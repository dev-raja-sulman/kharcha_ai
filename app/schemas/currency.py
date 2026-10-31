from datetime import date
from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class CurrencyInfo(BaseModel):
    code: str = Field(..., description="ISO 4217 Currency Code, e.g. PKR, USD, EUR")
    name: str = Field(..., description="Full Currency Name, e.g. Pakistani Rupee")
    symbol: str = Field(..., description="Display Symbol, e.g. PKR, $, €")
    rate_to_pkr: Decimal = Field(..., description="Exchange rate relative to PKR base")


class CurrencyListResponse(BaseModel):
    currencies: List[CurrencyInfo]
    base_currency: str = "PKR"


class CurrencyRateItem(BaseModel):
    from_currency: str
    to_currency: str
    rate: Decimal
    effective_date: date

    model_config = ConfigDict(from_attributes=True)


class CurrencyRatesResponse(BaseModel):
    rates: List[CurrencyRateItem]
    base_currency: str = "PKR"


class CurrencyConversionRequest(BaseModel):
    amount: Decimal = Field(..., gt=Decimal("0.00"), description="Monetary amount to convert")
    from_currency: str = Field(..., min_length=3, max_length=10)
    to_currency: str = Field(..., min_length=3, max_length=10)


class CurrencyConversionResponse(BaseModel):
    original_amount: Decimal
    original_currency: str
    converted_amount: Decimal
    target_currency: str
    exchange_rate: Decimal
    conversion_date: date
    is_converted: bool
    label: str = Field(..., description="Clear user-facing label e.g. 'Converted from USD 100.00 @ 278.50'")
