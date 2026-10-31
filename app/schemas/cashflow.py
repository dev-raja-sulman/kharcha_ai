from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class DailyCashflowPoint(BaseModel):
    date: str
    income: Decimal
    expense: Decimal
    net: Decimal


class CashflowOverviewResponse(BaseModel):
    month: int
    year: int
    currency: str = "PKR"
    total_income: Decimal
    total_expenses: Decimal
    net_cashflow: Decimal
    savings_rate: float = Field(..., description="Percentage of income saved: (Net Savings / Total Income) * 100")
    total_budget: Optional[Decimal] = None
    remaining_budget: Optional[Decimal] = None
    budget_used_percentage: Optional[float] = None
    health_status: str = Field(..., description="'surplus' | 'deficit' | 'balanced' | 'no_data'")
    health_title: str
    health_summary: str
    daily_trends: List[DailyCashflowPoint]

    model_config = ConfigDict(from_attributes=True)
