from datetime import date
from decimal import Decimal, ROUND_HALF_UP
import logging
from typing import Dict, List, Optional
from sqlalchemy.orm import Session

from app.models.currency import ExchangeRate, SupportedCurrency

logger = logging.getLogger(__name__)


class ExchangeRateService:
    """
    Exchange rate management and conversion service for KharchaAI.
    Enforces exact Decimal precision, strict validation against supported currencies,
    and never invents rates without verified database records.
    """

    @classmethod
    def get_supported_currencies(cls) -> List[str]:
        return SupportedCurrency.ALL

    @classmethod
    def get_rate(
        cls,
        db: Session,
        from_currency: str,
        to_currency: str,
        effective_on: Optional[date] = None
    ) -> Optional[Decimal]:
        """
        Retrieves the exact exchange rate between two currencies.
        Returns 1.0 if identical.
        Tries direct rate, then inverse rate, then triangular pivot via PKR base.
        Returns None if no verified path exists.
        """
        f_curr = from_currency.strip().upper()
        t_curr = to_currency.strip().upper()

        if f_curr == t_curr:
            return Decimal("1.000000")

        if not SupportedCurrency.is_valid(f_curr) or not SupportedCurrency.is_valid(t_curr):
            logger.warning(f"Unsupported currency pair: {f_curr} -> {t_curr}")
            return None

        from app.services.currency_service import CurrencyService
        CurrencyService.ensure_baseline_rates(db)

        # 1. Direct rate lookup
        query = db.query(ExchangeRate).filter(
            ExchangeRate.from_currency == f_curr,
            ExchangeRate.to_currency == t_curr
        )
        if effective_on:
            direct = query.filter(ExchangeRate.effective_date <= effective_on).order_by(
                ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()
            ).first()
            if not direct:
                direct = query.order_by(ExchangeRate.effective_date.asc(), ExchangeRate.id.desc()).first()
        else:
            direct = query.order_by(ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()).first()

        if direct:
            return Decimal(str(direct.rate))

        # 2. Reverse rate lookup (1 / rate)
        rev_query = db.query(ExchangeRate).filter(
            ExchangeRate.from_currency == t_curr,
            ExchangeRate.to_currency == f_curr
        )
        if effective_on:
            reverse = rev_query.filter(ExchangeRate.effective_date <= effective_on).order_by(
                ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()
            ).first()
            if not reverse:
                reverse = rev_query.order_by(ExchangeRate.effective_date.asc(), ExchangeRate.id.desc()).first()
        else:
            reverse = rev_query.order_by(ExchangeRate.effective_date.desc(), ExchangeRate.id.desc()).first()

        if reverse and Decimal(str(reverse.rate)) > Decimal("0"):
            rev_rate = Decimal("1.000000") / Decimal(str(reverse.rate))
            return rev_rate.quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)

        # 3. Triangular pivot via base PKR
        if f_curr != SupportedCurrency.PKR and t_curr != SupportedCurrency.PKR:
            rate_f_to_pkr = cls.get_rate(db, f_curr, SupportedCurrency.PKR, effective_on)
            rate_pkr_to_t = cls.get_rate(db, SupportedCurrency.PKR, t_curr, effective_on)
            if rate_f_to_pkr is not None and rate_pkr_to_t is not None:
                pivot_rate = rate_f_to_pkr * rate_pkr_to_t
                return pivot_rate.quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)

        return None

    @classmethod
    def convert(
        cls,
        db: Session,
        amount: Decimal,
        from_currency: str,
        to_currency: str,
        effective_on: Optional[date] = None
    ) -> Optional[Decimal]:
        """
        Converts an exact amount from one currency to another using stored exchange rates.
        Returns None if no exchange rate is found (protects against guessing rates).
        Result rounded to 2 decimal places.
        """
        rate = cls.get_rate(db, from_currency, to_currency, effective_on)
        if rate is None:
            return None

        converted = Decimal(str(amount)) * rate
        return converted.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

    @classmethod
    def get_latest_rates(cls, db: Session) -> List[Dict[str, object]]:
        rates = db.query(ExchangeRate).order_by(
            ExchangeRate.from_currency,
            ExchangeRate.to_currency
        ).all()
        return [
            {
                "id": r.id,
                "from_currency": r.from_currency,
                "to_currency": r.to_currency,
                "rate": float(r.rate),
                "effective_date": r.effective_date.isoformat(),
            }
            for r in rates
        ]
