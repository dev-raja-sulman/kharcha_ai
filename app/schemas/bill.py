from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


class BillBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=150, description="Title of bill (e.g. LESCO Electricity, Fiber Internet)")
    category: str = Field("Other", max_length=50, description="Electricity | Gas | Internet | Mobile | Rent | Education | Subscriptions | Other")
    amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Bill amount to pay"
    )
    due_date: date = Field(..., description="Due date for the bill")
    frequency: str = Field("one_time", description="one_time | monthly | quarterly | yearly")
    reminder_enabled: bool = Field(True, description="Enable notification / reminders for this bill")

    @field_validator("title")
    @classmethod
    def title_not_blank(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Bill title cannot be blank or whitespace-only.")
        return cleaned


class BillCreate(BillBase):
    pass


class BillUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=150)
    category: Optional[str] = Field(None, max_length=50)
    amount: Optional[Decimal] = Field(None, gt=Decimal("0.00"), decimal_places=2, max_digits=12)
    due_date: Optional[date] = None
    frequency: Optional[str] = None
    reminder_enabled: Optional[bool] = None
    status: Optional[str] = Field(None, description="unpaid | paid | overdue")

    @field_validator("title")
    @classmethod
    def title_not_blank(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            cleaned = v.strip()
            if not cleaned:
                raise ValueError("Bill title cannot be blank or whitespace-only.")
            return cleaned
        return v


class MarkPaidRequest(BaseModel):
    paid_date: Optional[date] = Field(default_factory=date.today)
    create_expense: bool = Field(
        True,
        description="If True, automatically logs an Expense linked to this bill without double-counting"
    )
    payment_method: str = Field("Bank Transfer", max_length=50)


class BillResponse(BillBase):
    id: int
    user_id: int
    status: str
    paid_date: Optional[date] = None
    linked_expense_id: Optional[int] = None
    is_overdue: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class BillListResponse(BaseModel):
    total: int
    total_amount: Decimal
    items: List[BillResponse]


class BillSummaryResponse(BaseModel):
    total_pending_amount: Decimal
    pending_count: int
    total_overdue_amount: Decimal
    overdue_count: int
    total_paid_this_month: Decimal
    paid_count_this_month: int
    upcoming_bills: List[BillResponse]
