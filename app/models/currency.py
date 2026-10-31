from datetime import date, datetime, timezone
from decimal import Decimal
from sqlalchemy import Column, Date, DateTime, Index, Integer, Numeric, String
from app.db.base import Base


class SupportedCurrency:
    PKR = "PKR"
    USD = "USD"
    EUR = "EUR"
    GBP = "GBP"
    AED = "AED"
    SAR = "SAR"
    INR = "INR"
    CAD = "CAD"
    AUD = "AUD"

    ALL = [PKR, USD, EUR, GBP, AED, SAR, INR, CAD, AUD]

    METADATA = {
        "PKR": {"name": "Pakistani Rupee", "symbol": "PKR", "locale": "en_PK"},
        "USD": {"name": "US Dollar", "symbol": "$", "locale": "en_US"},
        "EUR": {"name": "Euro", "symbol": "€", "locale": "de_DE"},
        "GBP": {"name": "British Pound", "symbol": "£", "locale": "en_GB"},
        "AED": {"name": "UAE Dirham", "symbol": "AED", "locale": "ar_AE"},
        "SAR": {"name": "Saudi Riyal", "symbol": "SAR", "locale": "ar_SA"},
        "INR": {"name": "Indian Rupee", "symbol": "₹", "locale": "en_IN"},
        "CAD": {"name": "Canadian Dollar", "symbol": "CA$", "locale": "en_CA"},
        "AUD": {"name": "Australian Dollar", "symbol": "AU$", "locale": "en_AU"},
    }

    @classmethod
    def is_valid(cls, currency: str) -> bool:
        return currency.upper() in cls.ALL


class ExchangeRate(Base):
    """
    SQLAlchemy model for storing verified currency exchange rates.
    Stores Decimal conversion rates with 6 decimal places of precision.
    """
    __tablename__ = "exchange_rates"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    from_currency = Column(String(10), nullable=False, index=True)
    to_currency = Column(String(10), nullable=False, index=True)
    rate = Column(Numeric(16, 6), nullable=False)
    effective_date = Column(Date, nullable=False, default=date.today)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    __table_args__ = (
        Index("ix_exchange_rates_pair_date", "from_currency", "to_currency", "effective_date"),
    )

    def __repr__(self) -> str:
        return f"<ExchangeRate 1 {self.from_currency} = {self.rate} {self.to_currency} ({self.effective_date})>"
