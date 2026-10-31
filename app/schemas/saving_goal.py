from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


class ContributionCreate(BaseModel):
    amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Contribution amount to add to savings goal"
    )
    contribution_date: date = Field(default_factory=date.today)
    notes: Optional[str] = Field(None, max_length=255)


class ContributionResponse(BaseModel):
    id: int
    goal_id: int
    user_id: int
    amount: Decimal
    contribution_date: date
    notes: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SavingGoalBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=150, description="Title of goal e.g. Buy Laptop, Hajj, Emergency Fund")
    description: Optional[str] = Field(None, max_length=500)
    target_amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Target financial goal amount"
    )
    start_date: date = Field(default_factory=date.today)
    target_date: date = Field(..., description="Target completion date")

    @field_validator("title")
    @classmethod
    def title_not_blank(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Goal title cannot be blank or whitespace-only.")
        return cleaned

    @field_validator("target_date")
    @classmethod
    def target_after_start(cls, v: date, values) -> date:
        # Pydantic v2 validation
        return v


class SavingGoalCreate(SavingGoalBase):
    pass


class SavingGoalUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=150)
    description: Optional[str] = Field(None, max_length=500)
    target_amount: Optional[Decimal] = Field(None, gt=Decimal("0.00"), decimal_places=2, max_digits=12)
    target_date: Optional[date] = None
    status: Optional[str] = Field(None, description="in_progress | completed | cancelled")

    @field_validator("title")
    @classmethod
    def title_not_blank(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            cleaned = v.strip()
            if not cleaned:
                raise ValueError("Goal title cannot be blank or whitespace-only.")
            return cleaned
        return v


class SavingGoalResponse(SavingGoalBase):
    id: int
    user_id: int
    current_amount: Decimal
    status: str
    remaining_amount: Decimal
    progress_percentage: float
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SavingGoalListResponse(BaseModel):
    total: int
    total_savings: Decimal
    items: List[SavingGoalResponse]
