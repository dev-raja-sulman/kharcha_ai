from calendar import monthrange
from datetime import date
from decimal import Decimal
import logging
from typing import Any, Dict, List, Optional
from sqlalchemy.orm import Session

from app.models.budget import Budget
from app.models.expense import Expense
from app.models.income import Income
from app.models.user import User
from app.schemas.cashflow import CashflowOverviewResponse, DailyCashflowPoint
from app.services.exchange_rate_service import ExchangeRateService

logger = logging.getLogger(__name__)


class CashflowService:
    """
    Computes cashflow metrics, savings rate, financial health analysis,
    and daily cashflow trend points for KharchaAI financial dashboard.
    Enforces multi-currency accuracy and protects against mixing unaligned currencies.
    """

    @classmethod
    def get_cashflow_overview(
        cls,
        db: Session,
        user_id: int,
        month: Optional[int] = None,
        year: Optional[int] = None,
        target_currency: Optional[str] = None
    ) -> CashflowOverviewResponse:
        today = date.today()
        target_month = month if month is not None else today.month
        target_year = year if year is not None else today.year

        # Determine target display currency from user preference if not explicitly provided
        user = db.query(User).filter(User.id == user_id).first()
        display_currency = (
            target_currency.strip().upper()
            if target_currency
            else (user.preferred_currency if user and user.preferred_currency else "PKR")
        )

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

        # 4. Multi-currency tracking and conversion
        total_income = Decimal("0.00")
        total_expenses = Decimal("0.00")
        by_currency: Dict[str, Dict[str, Decimal]] = {
            "incomes": {},
            "expenses": {}
        }

        # Daily trends grouping
        daily_map: Dict[int, Dict[str, Decimal]] = {
            d: {"income": Decimal("0.00"), "expense": Decimal("0.00")}
            for d in range(1, last_day + 1)
        }

        # Process Incomes
        for inc in incomes:
            raw_amt = Decimal(str(inc.amount))
            i_curr = (inc.currency or "PKR").upper().strip()
            by_currency["incomes"][i_curr] = by_currency["incomes"].get(i_curr, Decimal("0.00")) + raw_amt

            if i_curr == display_currency:
                converted_amt = raw_amt
            else:
                converted = ExchangeRateService.convert(
                    db=db,
                    amount=raw_amt,
                    from_currency=i_curr,
                    to_currency=display_currency,
                    effective_on=inc.income_date
                )
                converted_amt = converted if converted is not None else Decimal("0.00")

            total_income += converted_amt
            day_num = inc.income_date.day
            if day_num in daily_map:
                daily_map[day_num]["income"] += converted_amt

        # Process Expenses
        for exp in expenses:
            raw_amt = Decimal(str(exp.amount))
            e_curr = (exp.currency or "PKR").upper().strip()
            by_currency["expenses"][e_curr] = by_currency["expenses"].get(e_curr, Decimal("0.00")) + raw_amt

            if e_curr == display_currency:
                converted_amt = raw_amt
            else:
                converted = ExchangeRateService.convert(
                    db=db,
                    amount=raw_amt,
                    from_currency=e_curr,
                    to_currency=display_currency,
                    effective_on=exp.expense_date
                )
                converted_amt = converted if converted is not None else Decimal("0.00")

            total_expenses += converted_amt
            day_num = exp.expense_date.day
            if day_num in daily_map:
                daily_map[day_num]["expense"] += converted_amt

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
            b_raw = Decimal(str(overall_budget.amount))
            b_curr = (getattr(overall_budget, "currency", "PKR") or "PKR").upper().strip()
            if b_curr == display_currency:
                total_budget = b_raw
            else:
                converted_b = ExchangeRateService.convert(
                    db=db,
                    amount=b_raw,
                    from_currency=b_curr,
                    to_currency=display_currency,
                    effective_on=overall_budget.start_date
                )
                total_budget = converted_b if converted_b is not None else b_raw

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
                f"Great financial health! You have a net positive surplus of {display_currency} {net_cashflow:,.2f} "
                f"with a savings rate of {savings_rate:.1f}% this month."
            )
        elif net_cashflow < Decimal("0.00"):
            health_status = "deficit"
            health_title = "Operating at a Deficit"
            deficit_amount = abs(net_cashflow)
            health_summary = (
                f"Your expenses exceed your income by {display_currency} {deficit_amount:,.0f} this month. "
                "Review discretionary purchases and recurring bills to regain balance."
            )
        else:
            health_status = "balanced"
            health_title = "Balanced Break-Even"
            health_summary = (
                f"Your recorded monthly income matches your expenses exactly ({display_currency} 0.00 net). "
                "Consider setting a savings goal to start building wealth."
            )

        # 8. Daily Trends
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

        # Format by_currency serializable dictionary
        by_currency_serialized = {
            "incomes": {k: float(v) for k, v in by_currency["incomes"].items()},
            "expenses": {k: float(v) for k, v in by_currency["expenses"].items()},
        }

        return CashflowOverviewResponse(
            month=target_month,
            year=target_year,
            currency=display_currency,
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
            by_currency=by_currency_serialized,
            daily_trends=daily_trends
        )
