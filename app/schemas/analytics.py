from datetime import date
from decimal import Decimal
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class InsightSeverity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    SUCCESS = "success"


class DailySpendingPoint(BaseModel):
    date: date
    amount: Decimal
    day_name: str

    model_config = ConfigDict(from_attributes=True)


class WeeklySpendingPoint(BaseModel):
    week_label: str
    start_date: date
    end_date: date
    amount: Decimal

    model_config = ConfigDict(from_attributes=True)


class CategorySpendingPoint(BaseModel):
    category: str
    amount: Decimal
    percentage: float
    count: int

    model_config = ConfigDict(from_attributes=True)


class MonthComparison(BaseModel):
    current_month_total: Decimal
    previous_month_total: Decimal
    difference: Decimal
    percentage_change: float
    trend: str  # "increased", "decreased", "unchanged", "no_previous_data"

    model_config = ConfigDict(from_attributes=True)


class BudgetVsActual(BaseModel):
    total_budgeted: Decimal
    total_spent: Decimal
    remaining: Decimal
    percentage_used: float

    model_config = ConfigDict(from_attributes=True)


class SpendingAnalyticsResponse(BaseModel):
    month: int
    year: int
    total_spent: Decimal
    total_transactions: int
    average_daily_spending: Decimal
    highest_spending_category: Optional[CategorySpendingPoint] = None
    category_breakdown: List[CategorySpendingPoint] = []
    daily_spending: List[DailySpendingPoint] = []
    weekly_spending: List[WeeklySpendingPoint] = []
    month_comparison: MonthComparison
    budget_vs_actual: Optional[BudgetVsActual] = None
    disclaimer: str = "Analytics are calculated solely from recorded expenses in KharchaAI."

    model_config = ConfigDict(from_attributes=True)


class SpendingInsightItem(BaseModel):
    type: str  # e.g. "top_category", "mom_comparison", "budget_status", "daily_rate", "milestone"
    title: str
    message: str
    severity: InsightSeverity = InsightSeverity.INFO
    category: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class SpendingInsightsResponse(BaseModel):
    month: int
    year: int
    headline: str
    insights: List[SpendingInsightItem] = []
    is_ai_generated: bool = False
    provider_used: str = "deterministic_rules"
    disclaimer: str = (
        "Insights are evidence-based observations generated from recorded transactions. "
        "They do not represent bank account balances or investment advice."
    )

    model_config = ConfigDict(from_attributes=True)
