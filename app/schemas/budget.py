from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.expense import ExpenseCategory


class BudgetAlertLevel(str, Enum):
    NORMAL = "normal"          # < 50%
    WARNING_50 = "warning_50"  # 50% - 79.99%
    WARNING_80 = "warning_80"  # 80% - 99.99%
    EXCEEDED_100 = "exceeded_100"  # >= 100%


class BudgetCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="Name of the budget (e.g. 'Monthly Food', 'Overall October')")
    amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Budget ceiling amount, must be greater than zero"
    )
    category: Optional[str] = Field(
        default=None,
        description="Expense category for this budget. Null/None creates an overall monthly budget."
    )
    month: int = Field(..., ge=1, le=12, description="Target budget month (1 to 12)")
    year: int = Field(..., ge=2020, le=2100, description="Target budget year (e.g. 2026)")

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: Optional[str]) -> Optional[str]:
        if v is None or not str(v).strip() or str(v).lower() in ("all", "overall", "none", "null"):
            return None
        clean = ExpenseCategory.normalize(str(v).strip())
        return clean

    @field_validator("name")
    @classmethod
    def sanitize_name(cls, v: str) -> str:
        clean = v.strip()
        if not clean:
            raise ValueError("Budget name cannot be empty or whitespace only.")
        return clean


class BudgetUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    amount: Optional[Decimal] = Field(
        None,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Updated budget amount"
    )

    @field_validator("name")
    @classmethod
    def sanitize_name(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            clean = v.strip()
            if not clean:
                raise ValueError("Budget name cannot be empty.")
            return clean
        return v


class BudgetResponse(BaseModel):
    id: int
    user_id: int
    name: str
    amount: Decimal
    category: Optional[str] = None
    month: int
    year: int
    start_date: date
    end_date: date
    spent: Decimal = Decimal("0.00")
    remaining: Decimal = Decimal("0.00")
    percentage_used: float = 0.0
    alert_level: BudgetAlertLevel = BudgetAlertLevel.NORMAL
    alert_message: str = "Spending is well within budget limits."
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class BudgetListResponse(BaseModel):
    total: int
    items: List[BudgetResponse]
    month: int
    year: int
    total_budgeted: Decimal
    total_spent: Decimal
    overall_percentage: float

    model_config = ConfigDict(from_attributes=True)


class BudgetProgressSummaryResponse(BaseModel):
    month: int
    year: int
    overall_budget: Optional[BudgetResponse] = None
    category_budgets: List[BudgetResponse] = []
    active_alerts: List[dict] = []
    disclaimer: str = (
        "Budget calculations and alerts are estimates based on recorded expenses in KharchaAI, "
        "not real-time bank balances."
    )

    model_config = ConfigDict(from_attributes=True)
