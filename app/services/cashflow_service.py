from calendar import monthrange
from datetime import date
from decimal import Decimal
import logging
from typing import List, Optional
from sqlalchemy.orm import Session

from app.models.budget import Budget
from app.models.expense import Expense
from app.models.income import Income
from app.schemas.cashflow import CashflowOverviewResponse, DailyCashflowPoint

logger = logging.getLogger(__name__)


class CashflowService:
    """
    Computes cashflow metrics, savings rate, financial health analysis,
    and daily cashflow trend points for KharchaAI financial dashboard.
    """

    @classmethod
    def get_cashflow_overview(
        cls,
        db: Session,
        user_id: int,
        month: Optional[int] = None,
        year: Optional[int] = None
    ) -> CashflowOverviewResponse:
        today = date.today()
        target_month = month if month is not None else today.month
        target_year = year if year is not None else today.year

        _, last_day = monthrange(target_year, target_month)
        start_date = date(target_year, target_month, 1)
        end_date = date(target_year, target_month, last_day)

        # 1. Query incomes for the target month
        incomes = db.query(Income).filter(
            Income.user_id == user_id,
            Income.income_date >= start_date,
            Income.income_date <= end_date
        ).all()

        # 2. Query expenses for the target month
        expenses = db.query(Expense).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= start_date,
            Expense.expense_date <= end_date
        ).all()

        # 3. Query overall monthly budget
        overall_budget = db.query(Budget).filter(
            Budget.user_id == user_id,
            Budget.month == target_month,
            Budget.year == target_year,
            Budget.category.is_(None)
        ).first()

        # 4. Accurate Decimal summations
        total_income = sum((Decimal(str(i.amount)) for i in incomes), Decimal("0.00"))
        total_expenses = sum((Decimal(str(e.amount)) for e in expenses), Decimal("0.00"))
        net_cashflow = total_income - total_expenses

        # 5. Calculate Savings Rate safely (guarded against zero division)
        net_savings = max(Decimal("0.00"), net_cashflow)
        savings_rate = (
            round((float(net_savings) / float(total_income) * 100.0), 2)
            if total_income > Decimal("0.00")
            else 0.0
        )

        # 6. Budget Progress calculations
        total_budget: Optional[Decimal] = None
        remaining_budget: Optional[Decimal] = None
        budget_used_percentage: Optional[float] = None

        if overall_budget:
            total_budget = Decimal(str(overall_budget.amount))
            remaining_budget = total_budget - total_expenses
            budget_used_percentage = (
                round((float(total_expenses) / float(total_budget) * 100.0), 2)
                if total_budget > Decimal("0.00")
                else 0.0
            )

        # 7. Financial Health Evaluation
        if len(incomes) == 0 and len(expenses) == 0:
            health_status = "no_data"
            health_title = "No Activity Recorded"
            health_summary = (
                f"No income or expense records found for {target_year}-{target_month:02d}. "
                "Log your transactions to generate financial health insights."
            )
        elif net_cashflow > Decimal("0.00"):
            health_status = "surplus"
            health_title = "Positive Cashflow Surplus"
            health_summary = (
                f"Great financial health! You have a net positive surplus of PKR {net_cashflow:,.2f} "
                f"with a savings rate of {savings_rate:.1f}% this month."
            )
        elif net_cashflow < Decimal("0.00"):
            health_status = "deficit"
            health_title = "Operating at a Deficit"
            deficit_amount = abs(net_cashflow)
            health_summary = (
                f"Warning: Your recorded expenses exceed your income by PKR {deficit_amount:,.2f}. "
                "Review discretionary purchases and recurring bills to regain balance."
            )
        else:
            health_status = "balanced"
            health_title = "Balanced Break-Even"
            health_summary = (
                "Your recorded monthly income matches your expenses exactly (PKR 0.00 net). "
                "Consider setting a savings goal to start building wealth."
            )

        # 8. Daily Trends (Group by day)
        daily_map = {d: {"income": Decimal("0.00"), "expense": Decimal("0.00")} for d in range(1, last_day + 1)}
        for inc in incomes:
            day_num = inc.income_date.day
            if day_num in daily_map:
                daily_map[day_num]["income"] += Decimal(str(inc.amount))

        for exp in expenses:
            day_num = exp.expense_date.day
            if day_num in daily_map:
                daily_map[day_num]["expense"] += Decimal(str(exp.amount))

        daily_trends: List[DailyCashflowPoint] = []
        for day_num in sorted(daily_map.keys()):
            d_income = daily_map[day_num]["income"]
            d_expense = daily_map[day_num]["expense"]
            d_net = d_income - d_expense
            date_str = f"{target_year}-{target_month:02d}-{day_num:02d}"
            daily_trends.append(DailyCashflowPoint(
                date=date_str,
                income=d_income,
                expense=d_expense,
                net=d_net
            ))

        return CashflowOverviewResponse(
            month=target_month,
            year=target_year,
            currency="PKR",
            total_income=total_income,
            total_expenses=total_expenses,
            net_cashflow=net_cashflow,
            savings_rate=savings_rate,
            total_budget=total_budget,
            remaining_budget=remaining_budget,
            budget_used_percentage=budget_used_percentage,
            health_status=health_status,
            health_title=health_title,
            health_summary=health_summary,
            daily_trends=daily_trends
        )
