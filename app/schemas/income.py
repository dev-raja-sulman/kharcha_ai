from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


# ---------------------------------------------------------------------------
# Income Source Schemas
# ---------------------------------------------------------------------------

class IncomeSourceBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="Name of income source (e.g. Salary, Freelance)")
    description: Optional[str] = Field(None, max_length=255)
    is_active: bool = Field(True, description="Whether this source is currently active")


class IncomeSourceCreate(IncomeSourceBase):
    pass


class IncomeSourceResponse(IncomeSourceBase):
    id: int
    user_id: Optional[int] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Income Transaction Schemas
# ---------------------------------------------------------------------------

class IncomeBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=150, description="Title of the income entry")
    amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Income amount, must be greater than zero"
    )
    currency: str = Field("PKR", min_length=3, max_length=10, description="ISO currency code or symbol")
    income_date: date = Field(default_factory=date.today, description="Date income was earned or received")
    payment_method: str = Field("Bank Transfer", max_length=50, description="Payment method: Bank Transfer, Cash, Card, EasyPaisa, etc.")
    description: Optional[str] = Field(None, max_length=500, description="Optional description or notes")
    source_id: Optional[int] = Field(None, description="Optional foreign key to income_sources")

    @field_validator("title")
    @classmethod
    def title_must_not_be_blank(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Income title cannot be blank or whitespace-only.")
        return cleaned


class IncomeCreate(IncomeBase):
    pass


class IncomeUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=150)
    amount: Optional[Decimal] = Field(None, gt=Decimal("0.00"), decimal_places=2, max_digits=12)
    currency: Optional[str] = Field(None, min_length=3, max_length=10)
    income_date: Optional[date] = None
    payment_method: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = Field(None, max_length=500)
    source_id: Optional[int] = None

    @field_validator("title")
    @classmethod
    def title_must_not_be_blank(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            cleaned = v.strip()
            if not cleaned:
                raise ValueError("Income title cannot be blank or whitespace-only.")
            return cleaned
        return v


class IncomeResponse(IncomeBase):
    id: int
    user_id: int
    source_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class IncomeListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    total_amount: Decimal
    items: List[IncomeResponse]


class SourceBreakdownItem(BaseModel):
    source_id: Optional[int] = None
    source_name: str
    total_amount: Decimal
    percentage: float
    transaction_count: int


class IncomeSummaryResponse(BaseModel):
    total_income: Decimal
    total_transactions: int
    currency: str = "PKR"
    month: Optional[int] = None
    year: Optional[int] = None
    source_breakdown: List[SourceBreakdownItem]
    average_income_per_entry: Decimal
