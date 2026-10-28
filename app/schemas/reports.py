from datetime import date
from decimal import Decimal
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ReportType(str, Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    YEARLY = "yearly"
    CUSTOM = "custom"
    CATEGORY = "category"


class CategoryReportItem(BaseModel):
    category: str
    total_amount: Decimal
    percentage: float
    count: int

    model_config = ConfigDict(from_attributes=True)


class TrendPoint(BaseModel):
    label: str
    point_date: Optional[date] = None
    amount: Decimal
    count: int

    model_config = ConfigDict(from_attributes=True)


class RecurringVsRegularBreakdown(BaseModel):
    recurring_amount: Decimal
    recurring_count: int
    recurring_percentage: float
    regular_amount: Decimal
    regular_count: int
    regular_percentage: float

    model_config = ConfigDict(from_attributes=True)


class PeriodComparisonData(BaseModel):
    previous_start_date: date
    previous_end_date: date
    previous_expenditure: Decimal
    previous_count: int
    difference: Decimal
    percentage_change: float
    trend: str  # "increased", "decreased", "unchanged", "no_previous_data"

    model_config = ConfigDict(from_attributes=True)


class AdvancedReportResponse(BaseModel):
    report_type: str
    start_date: date
    end_date: date
    total_expenditure: Decimal
    total_expenses: int
    average_daily_spending: Decimal
    highest_spending_category: Optional[CategoryReportItem] = None
    category_breakdown: List[CategoryReportItem] = []
    spending_trends: List[TrendPoint] = []
    recurring_vs_regular: RecurringVsRegularBreakdown
    period_comparison: Optional[PeriodComparisonData] = None
    generated_at: str

    model_config = ConfigDict(from_attributes=True)
