from datetime import date
from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

from app.schemas.cashflow import DailyCashflowPoint
from app.schemas.expense import ExpenseResponse
from app.schemas.financial_advisor import AdvisorInsightItem
from app.schemas.income import IncomeResponse
from app.schemas.bill import BillResponse


class DashboardSummaryCards(BaseModel):
    monthly_income: Decimal = Field(..., description="Sum of income transactions in the selected month")
    monthly_expenses: Decimal = Field(..., description="Sum of expense transactions in the selected month")
    net_cashflow: Decimal = Field(..., description="Monthly Income - Monthly Expenses")
    monthly_savings: Decimal = Field(..., description="Retained savings (max 0, net_cashflow)")
    savings_rate: float = Field(..., description="(Net Cashflow / Monthly Income) * 100")
    is_deficit: bool = Field(False, description="True if expenses exceed income in the selected month")
    deficit_warning_message: Optional[str] = Field(None, description="Formatted warning text if operating at deficit")


class IncomeVsExpenseComparison(BaseModel):
    current_month_income: Decimal
    current_month_expenses: Decimal
    current_month_net: Decimal
    prev_month_income: Decimal
    prev_month_expenses: Decimal
    prev_month_net: Decimal


class DashboardCategorySpending(BaseModel):
    category: str
    amount: Decimal
    percentage: float
    transaction_count: int


class DashboardBudgetStatus(BaseModel):
    total_budget: Optional[Decimal] = None
    budget_spent: Optional[Decimal] = None
    remaining_budget: Optional[Decimal] = None
    percentage_used: Optional[float] = None
    is_over_budget: bool = False


class DashboardFinancialSummaryResponse(BaseModel):
    month: int
    year: int
    currency: str = "PKR"
    summary_cards: DashboardSummaryCards
    comparison: IncomeVsExpenseComparison
    category_breakdown: List[DashboardCategorySpending]
    daily_trends: List[DailyCashflowPoint]
    recent_incomes: List[IncomeResponse]
    recent_expenses: List[ExpenseResponse]
    upcoming_bills: List[BillResponse]
    budget_status: Optional[DashboardBudgetStatus] = None
    ai_insights: List[AdvisorInsightItem] = []
    health_status: str
    health_title: str
    health_summary: str

    model_config = ConfigDict(from_attributes=True)
