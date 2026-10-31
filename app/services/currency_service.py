from datetime import date
from decimal import Decimal, ROUND_HALF_UP
import logging
from typing import Dict, List, Optional, Tuple

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.currency import ExchangeRate, SupportedCurrency
from app.schemas.currency import (
    CurrencyConversionResponse,
    CurrencyInfo,
    CurrencyListResponse,
    CurrencyRateItem,
    CurrencyRatesResponse,
)

logger = logging.getLogger(__name__)

BASELINE_EXCHANGE_RATES = [
    ("USD", "PKR", Decimal("278.500000")),
    ("PKR", "USD", Decimal("0.003591")),
    ("EUR", "PKR", Decimal("302.200000")),
    ("PKR", "EUR", Decimal("0.003309")),
    ("GBP", "PKR", Decimal("355.800000")),
    ("PKR", "GBP", Decimal("0.002811")),
    ("AED", "PKR", Decimal("75.800000")),
    ("PKR", "AED", Decimal("0.013193")),
    ("SAR", "PKR", Decimal("74.200000")),
    ("PKR", "SAR", Decimal("0.013477")),
    ("INR", "PKR", Decimal("3.320000")),
    ("PKR", "INR", Decimal("0.301205")),
    ("CAD", "PKR", Decimal("202.500000")),
    ("PKR", "CAD", Decimal("0.004938")),
    ("AUD", "PKR", Decimal("181.400000")),
    ("PKR", "AUD", Decimal("0.005513")),
]


class CurrencyService:
    """
    Core Financial Currency Service in KharchaAI.
    Enforces strict rules:
    - Pure Decimal arithmetic for monetary computations.
    - Verified exchange rate lookup.
    - Transparent conversion labeling.
    - Zero invented rates.
    """

    @classmethod
    def ensure_baseline_rates(cls, db: Session) -> None:
        """
        Seeds baseline reference rates if none exist in the database (e.g. testing or initial setup).
        """
        count = db.query(ExchangeRate).count()
        if count == 0:
            today = date.today()
            for from_c, to_c, rate in BASELINE_EXCHANGE_RATES:
                db.add(ExchangeRate(
                    from_currency=from_c,
                    to_currency=to_c,
                    rate=rate,
                    effective_date=today
                ))
            db.commit()

    @classmethod
    def get_supported_currencies(cls, db: Session) -> CurrencyListResponse:
        """
        Returns all supported currencies with names, symbols, and current rate to PKR.
        """
        cls.ensure_baseline_rates(db)
        currencies: List[CurrencyInfo] = []

        for code in SupportedCurrency.ALL:
            meta = SupportedCurrency.METADATA.get(code, {})
            name = meta.get("name", code)
            symbol = meta.get("symbol", code)

            if code == "PKR":
                rate_to_pkr = Decimal("1.000000")
            else:
                # Look up rate from currency to PKR
                rate_record = db.query(ExchangeRate).filter(
                    ExchangeRate.from_currency == code,
                    ExchangeRate.to_currency == "PKR"
                ).order_by(ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()).first()

                rate_to_pkr = Decimal(str(rate_record.rate)) if rate_record else Decimal("1.000000")

            currencies.append(CurrencyInfo(
                code=code,
                name=name,
                symbol=symbol,
                rate_to_pkr=rate_to_pkr
            ))

        return CurrencyListResponse(currencies=currencies, base_currency="PKR")

    @classmethod
    def get_all_rates(cls, db: Session) -> CurrencyRatesResponse:
        """
        Retrieves all currently stored exchange rates.
        """
        cls.ensure_baseline_rates(db)
        rates = db.query(ExchangeRate).order_by(
            ExchangeRate.from_currency,
            ExchangeRate.to_currency
        ).all()

        return CurrencyRatesResponse(
            rates=[CurrencyRateItem.model_validate(r) for r in rates],
            base_currency="PKR"
        )

    @classmethod
    def get_exchange_rate(
        cls,
        db: Session,
        from_currency: str,
        to_currency: str
    ) -> Optional[Tuple[Decimal, date]]:
        """
        Finds the latest verified exchange rate between two currencies.
        Direct rate or triangular conversion through PKR.
        Returns: (rate, effective_date) or None if rate is unavailable.
        """
        cls.ensure_baseline_rates(db)
        from_c = from_currency.upper().strip()
        to_c = to_currency.upper().strip()

        if from_c == to_c:
            return Decimal("1.000000"), date.today()

        # 1. Direct rate check
        direct = db.query(ExchangeRate).filter(
            ExchangeRate.from_currency == from_c,
            ExchangeRate.to_currency == to_c
        ).order_by(ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()).first()

        if direct:
            return Decimal(str(direct.rate)), direct.effective_date

        # 2. Inverted rate check
        inverted = db.query(ExchangeRate).filter(
            ExchangeRate.from_currency == to_c,
            ExchangeRate.to_currency == from_c
        ).order_by(ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()).first()

        if inverted and inverted.rate > 0:
            calc_rate = (Decimal("1.0") / Decimal(str(inverted.rate))).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)
            return calc_rate, inverted.effective_date

        # 3. Triangular via PKR
        to_pkr = db.query(ExchangeRate).filter(
            ExchangeRate.from_currency == from_c,
            ExchangeRate.to_currency == "PKR"
        ).order_by(ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()).first()

        pkr_to_target = db.query(ExchangeRate).filter(
            ExchangeRate.from_currency == "PKR",
            ExchangeRate.to_currency == to_c
        ).order_by(ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()).first()

        if to_pkr and pkr_to_target:
            combined_rate = (Decimal(str(to_pkr.rate)) * Decimal(str(pkr_to_target.rate))).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)
            eff_date = min(to_pkr.effective_date, pkr_to_target.effective_date)
            return combined_rate, eff_date

        return None

    @classmethod
    def convert_amount(
        cls,
        db: Session,
        amount: Decimal,
        from_currency: str,
        to_currency: str
    ) -> Tuple[Decimal, Decimal, date, bool]:
        """
        Converts monetary amount using verified exchange rate.
        Returns: (converted_amount, exchange_rate, conversion_date, is_converted)
        If from_currency == to_currency, returns (amount, 1.0, today, False).
        Raises HTTPException if conversion rate is missing (never silently invents rates).
        """
        from_c = from_currency.upper().strip()
        to_c = to_currency.upper().strip()

        if from_c == to_c:
            return amount, Decimal("1.000000"), date.today(), False

        rate_info = cls.get_exchange_rate(db, from_c, to_c)
        if not rate_info:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Verified exchange rate between {from_c} and {to_c} is not available. Never silently converting with invented rate."
            )

        rate, eff_date = rate_info
        converted = (Decimal(str(amount)) * rate).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        return converted, rate, eff_date, True

    @classmethod
    def format_conversion_label(
        cls,
        original_amount: Decimal,
        original_currency: str,
        converted_amount: Decimal,
        target_currency: str,
        rate: Decimal
    ) -> str:
        """
        Generates clean transparent audit label for converted values.
        """
        if original_currency.upper() == target_currency.upper():
            return f"{target_currency} {converted_amount:,.2f}"
        return (
            f"Converted from {original_currency} {original_amount:,.2f} "
            f"to {target_currency} {converted_amount:,.2f} (@ {rate:,.4f})"
        )
