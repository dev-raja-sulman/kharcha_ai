from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class RecurringFrequency(str, Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    YEARLY = "yearly"


class RecurringStatus(str, Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    CANCELLED = "cancelled"
    COMPLETED = "completed"


class RecurringExpenseCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=150, description="Title of the recurring expense")
    amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Amount per recurrence, must be greater than zero"
    )
    category: str = Field(..., description="Expense category")
    description: Optional[str] = Field(None, max_length=500, description="Optional notes or details")
    frequency: RecurringFrequency = Field(..., description="Recurrence frequency: daily, weekly, monthly, yearly")
    payment_method: Optional[str] = Field("Cash", max_length=50, description="Payment method used")
    start_date: Optional[date] = Field(default_factory=date.today, description="Start date of recurrence")
    end_date: Optional[date] = Field(None, description="Optional end date when recurrence stops")

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        clean = v.strip()
        if not clean:
            raise ValueError("Recurring expense title cannot be blank")
        return clean

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        clean = v.strip()
        if not clean:
            raise ValueError("Category cannot be blank")
        return clean.title()

    @model_validator(mode="after")
    def validate_dates(self) -> "RecurringExpenseCreateRequest":
        if self.end_date and self.start_date and self.end_date < self.start_date:
            raise ValueError("end_date must be on or after start_date")
        return self


class RecurringExpenseUpdateRequest(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=150)
    amount: Optional[Decimal] = Field(None, gt=Decimal("0.00"), decimal_places=2, max_digits=12)
    category: Optional[str] = None
    description: Optional[str] = Field(None, max_length=500)
    frequency: Optional[RecurringFrequency] = None
    payment_method: Optional[str] = Field(None, max_length=50)
    end_date: Optional[date] = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            clean = v.strip()
            if not clean:
                raise ValueError("Recurring expense title cannot be blank")
            return clean
        return v

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            clean = v.strip()
            if not clean:
                raise ValueError("Category cannot be blank")
            return clean.title()
        return v


class RecurringExpenseResponse(BaseModel):
    id: int
    user_id: int
    title: str
    amount: Decimal
    category: str
    description: Optional[str] = None
    frequency: str
    payment_method: str
    start_date: date
    end_date: Optional[date] = None
    next_scheduled_date: date
    last_generated_date: Optional[date] = None
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class RecurringExpenseListResponse(BaseModel):
    items: List[RecurringExpenseResponse]
    total: int


class RecurringProcessResponse(BaseModel):
    processed_rules: int
    generated_count: int
    message: str
