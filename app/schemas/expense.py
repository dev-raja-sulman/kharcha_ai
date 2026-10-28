from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


class ExpenseCategory(str, Enum):
    FOOD = "Food"
    TRANSPORT = "Transport"
    SHOPPING = "Shopping"
    BILLS = "Bills"
    HEALTHCARE = "Healthcare"
    EDUCATION = "Education"
    ENTERTAINMENT = "Entertainment"
    RENT = "Rent"
    TRAVEL = "Travel"
    OTHER = "Other"

    @classmethod
    def list_all(cls) -> List[str]:
        return [c.value for c in cls]

    @classmethod
    def normalize(cls, value: str) -> str:
        """
        Normalize input category string to match canonical casing or fallback to Other.
        """
        normalized_map = {c.value.lower(): c.value for c in cls}
        clean_val = value.strip().lower()
        if clean_val in normalized_map:
            return normalized_map[clean_val]
        # Check title case
        if value.title() in cls.list_all():
            return value.title()
        return cls.OTHER.value


class PaymentMethod(str, Enum):
    CASH = "Cash"
    CARD = "Card"
    BANK_TRANSFER = "Bank Transfer"
    EASYPAISA = "EasyPaisa"
    JAZZCASH = "JazzCash"
    OTHER = "Other"


# ---------------------------------------------------------------------------
# Request Schemas
# ---------------------------------------------------------------------------

class ExpenseCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=150, description="Short title of the expense")
    amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Expense amount, must be greater than zero"
    )
    category: str = Field(..., description="Expense category from standard category list")
    description: Optional[str] = Field(None, max_length=500, description="Optional notes or details")
    expense_date: Optional[date] = Field(default_factory=date.today, description="Date expense occurred")
    payment_method: Optional[str] = Field("Cash", max_length=50, description="Payment method used")

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        clean = v.strip()
        if not clean:
            raise ValueError("Expense title cannot be empty or blank")
        return clean

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        clean = v.strip()
        # Accept valid categories (case-insensitive) or preserve valid custom category
        valid_categories = {c.lower(): c for c in ExpenseCategory.list_all()}
        if clean.lower() in valid_categories:
            return valid_categories[clean.lower()]
        return clean.title()


class ExpenseUpdateRequest(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=150)
    amount: Optional[Decimal] = Field(None, gt=Decimal("0.00"), decimal_places=2, max_digits=12)
    category: Optional[str] = None
    description: Optional[str] = Field(None, max_length=500)
    expense_date: Optional[date] = None
    payment_method: Optional[str] = Field(None, max_length=50)

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            clean = v.strip()
            if not clean:
                raise ValueError("Expense title cannot be empty or blank")
            return clean
        return v

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            clean = v.strip()
            valid_categories = {c.lower(): c for c in ExpenseCategory.list_all()}
            if clean.lower() in valid_categories:
                return valid_categories[clean.lower()]
            return clean.title()
        return v


# ---------------------------------------------------------------------------
# Response Schemas
# ---------------------------------------------------------------------------

class ExpenseResponse(BaseModel):
    id: int
    user_id: int
    title: str
    amount: Decimal
    category: str
    description: Optional[str] = None
    expense_date: date
    payment_method: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CategorySummaryItem(BaseModel):
    category: str
    total_amount: Decimal
    count: int
    percentage: float


class PaymentMethodSummaryItem(BaseModel):
    payment_method: str
    total_amount: Decimal
    count: int


class ExpenseSummaryResponse(BaseModel):
    total_amount: Decimal
    total_count: int
    by_category: List[CategorySummaryItem]
    by_payment_method: List[PaymentMethodSummaryItem]
    start_date: Optional[date] = None
    end_date: Optional[date] = None


class ExpenseListResponse(BaseModel):
    items: List[ExpenseResponse]
    total: int
    skip: int
    limit: int
