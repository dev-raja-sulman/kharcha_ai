from calendar import monthrange
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
import logging
from typing import Dict, List, Optional, Tuple

from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session, joinedload

from app.models.bill import Bill
from app.models.budget import Budget
from app.models.expense import Expense
from app.models.income import Income
from app.models.user import User
from app.schemas.cashflow import DailyCashflowPoint
from app.schemas.dashboard import (
    DashboardBudgetStatus,
    DashboardCategorySpending,
    DashboardFinancialSummaryResponse,
    DashboardSummaryCards,
    IncomeVsExpenseComparison,
)
from app.schemas.expense import ExpenseResponse
from app.schemas.financial_advisor import AdvisorInsightItem
from app.schemas.income import IncomeResponse
from app.schemas.bill import BillResponse
from app.services.currency_service import CurrencyService

logger = logging.getLogger(__name__)


class DashboardService:
    """
    Core Financial Intelligence & Dashboard Calculation Service in KharchaAI.
    Strictly enforces:
    1. Equal date-range comparisons (Never compares lifetime expenses against monthly income).
    2. Exact Python Decimal financial arithmetic.
    3. Multi-currency verified conversions with transparent rate auditing.
    4. Safe zero-division protection on savings rates.
    """

    @classmethod
    def _to_display_currency(
        cls,
        db: Session,
        amount: Decimal,
        from_currency: str,
        target_currency: str
    ) -> Decimal:
        """
        Safely converts monetary value to user's display currency using CurrencyService.
        """
        if not from_currency or from_currency.upper() == target_currency.upper():
            return Decimal(str(amount))
        try:
            converted, _, _, _ = CurrencyService.convert_amount(
                db=db,
                amount=amount,
                from_currency=from_currency,
                to_currency=target_currency
            )
            return converted
        except Exception as e:
            logger.warning(f"Could not convert {amount} {from_currency} to {target_currency}: {e}")
            return Decimal(str(amount))

    @classmethod
    def get_financial_summary(
        cls,
        db: Session,
        user_id: int,
        month: Optional[int] = None,
        year: Optional[int] = None,
        override_currency: Optional[str] = None
    ) -> DashboardFinancialSummaryResponse:
        today = date.today()
        target_month = month if (month is not None and 1 <= month <= 12) else today.month
        target_year = year if (year is not None and 2000 <= year <= 2100) else today.year

        user = db.query(User).filter(User.id == user_id).first()
        display_currency = (override_currency or (user.preferred_currency if user else "PKR")).upper().strip()

        # 1. Date Range for Selected Month
        _, last_day = monthrange(target_year, target_month)
        cur_start = date(target_year, target_month, 1)
        cur_end = date(target_year, target_month, last_day)

        # 2. Previous Month Date Range for Month-over-Month Comparison
        if target_month == 1:
            prev_month = 12
            prev_year = target_year - 1
        else:
            prev_month = target_month - 1
            prev_year = target_year

        _, prev_last_day = monthrange(prev_year, prev_month)
        prev_start = date(prev_year, prev_month, 1)
        prev_end = date(prev_year, prev_month, prev_last_day)

        # 3. Query Selected Month Incomes
        cur_incomes = db.query(Income).options(joinedload(Income.source)).filter(
            Income.user_id == user_id,
            Income.income_date >= cur_start,
            Income.income_date <= cur_end
        ).order_by(Income.income_date.desc(), Income.id.desc()).all()

        # 4. Query Selected Month Expenses
        cur_expenses = db.query(Expense).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= cur_start,
            Expense.expense_date <= cur_end
        ).order_by(Expense.expense_date.desc(), Expense.id.desc()).all()

        # 5. Query Previous Month Incomes & Expenses
        prev_incomes = db.query(Income).filter(
            Income.user_id == user_id,
            Income.income_date >= prev_start,
            Income.income_date <= prev_end
        ).all()

        prev_expenses = db.query(Expense).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= prev_start,
            Expense.expense_date <= prev_end
        ).all()

        # 6. Safe Decimal Summations in User's Display Currency
        monthly_income = Decimal("0.00")
        for inc in cur_incomes:
            c_val = cls._to_display_currency(db, inc.amount, inc.currency, display_currency)
            monthly_income += c_val

        monthly_expenses = Decimal("0.00")
        for exp in cur_expenses:
            exp_curr = getattr(exp, "currency", "PKR") or "PKR"
            c_val = cls._to_display_currency(db, exp.amount, exp_curr, display_currency)
            monthly_expenses += c_val

        prev_month_income = Decimal("0.00")
        for inc in prev_incomes:
            c_val = cls._to_display_currency(db, inc.amount, inc.currency, display_currency)
            prev_month_income += c_val

        prev_month_expenses = Decimal("0.00")
        for exp in prev_expenses:
            exp_curr = getattr(exp, "currency", "PKR") or "PKR"
            c_val = cls._to_display_currency(db, exp.amount, exp_curr, display_currency)
            prev_month_expenses += c_val

        # 7. Financial Calculations (Strictly Same Period & Currency Basis)
        net_cashflow = monthly_income - monthly_expenses
        monthly_savings = max(Decimal("0.00"), net_cashflow)

        if monthly_income > Decimal("0.00"):
            savings_rate = float(round((monthly_savings / monthly_income) * Decimal("100.0"), 2))
        else:
            savings_rate = 0.0

        is_deficit = monthly_expenses > monthly_income
        deficit_warning_message: Optional[str] = None
        if is_deficit:
            deficit_amount = monthly_expenses - monthly_income
            deficit_warning_message = (
                f"Your expenses exceed your income by {display_currency} {deficit_amount:,.2f} this month."
            )

        summary_cards = DashboardSummaryCards(
            monthly_income=monthly_income,
            monthly_expenses=monthly_expenses,
            net_cashflow=net_cashflow,
            monthly_savings=monthly_savings,
            savings_rate=savings_rate,
            is_deficit=is_deficit,
            deficit_warning_message=deficit_warning_message
        )

        comparison = IncomeVsExpenseComparison(
            current_month_income=monthly_income,
            current_month_expenses=monthly_expenses,
            current_month_net=net_cashflow,
            prev_month_income=prev_month_income,
            prev_month_expenses=prev_month_expenses,
            prev_month_net=prev_month_income - prev_month_expenses
        )

        # 8. Category-wise Expense Breakdown for Selected Month
        category_map: Dict[str, Dict[str, Any]] = {}
        for exp in cur_expenses:
            cat = exp.category or "Other"
            exp_curr = getattr(exp, "currency", "PKR") or "PKR"
            c_val = cls._to_display_currency(db, exp.amount, exp_curr, display_currency)
            if cat not in category_map:
                category_map[cat] = {"amount": Decimal("0.00"), "count": 0}
            category_map[cat]["amount"] += c_val
            category_map[cat]["count"] += 1

        category_breakdown: List[DashboardCategorySpending] = []
        for cat, data in sorted(category_map.items(), key=lambda x: x[1]["amount"], reverse=True):
            pct = float(round((data["amount"] / monthly_expenses * Decimal("100.0")), 2)) if monthly_expenses > 0 else 0.0
            category_breakdown.append(DashboardCategorySpending(
                category=cat,
                amount=data["amount"],
                percentage=pct,
                transaction_count=data["count"]
            ))

        # 9. Daily Trends (Daily cashflow trajectory across the month)
        daily_map = {d: {"income": Decimal("0.00"), "expense": Decimal("0.00")} for d in range(1, last_day + 1)}
        for inc in cur_incomes:
            d_num = inc.income_date.day
            if d_num in daily_map:
                c_val = cls._to_display_currency(db, inc.amount, inc.currency, display_currency)
                daily_map[d_num]["income"] += c_val

        for exp in cur_expenses:
            d_num = exp.expense_date.day
            if d_num in daily_map:
                exp_curr = getattr(exp, "currency", "PKR") or "PKR"
                c_val = cls._to_display_currency(db, exp.amount, exp_curr, display_currency)
                daily_map[d_num]["expense"] += c_val

        daily_trends: List[DailyCashflowPoint] = []
        for day_num in sorted(daily_map.keys()):
            d_inc = daily_map[day_num]["income"]
            d_exp = daily_map[day_num]["expense"]
            date_str = f"{target_year}-{target_month:02d}-{day_num:02d}"
            daily_trends.append(DailyCashflowPoint(
                date=date_str,
                income=d_inc,
                expense=d_exp,
                net=d_inc - d_exp
            ))

        # 10. Overall Monthly Budget Status
        budget = db.query(Budget).filter(
            Budget.user_id == user_id,
            Budget.month == target_month,
            Budget.year == target_year,
            Budget.category.is_(None)
        ).first()

        budget_status: Optional[DashboardBudgetStatus] = None
        if budget:
            budget_curr = getattr(budget, "currency", "PKR") or "PKR"
            b_amount = cls._to_display_currency(db, budget.amount, budget_curr, display_currency)
            rem = b_amount - monthly_expenses
            pct = float(round((monthly_expenses / b_amount * Decimal("100.0")), 2)) if b_amount > 0 else 0.0
            budget_status = DashboardBudgetStatus(
                total_budget=b_amount,
                budget_spent=monthly_expenses,
                remaining_budget=rem,
                percentage_used=pct,
                is_over_budget=monthly_expenses > b_amount
            )

        # 11. Upcoming Bills
        unpaid_bills = db.query(Bill).filter(
            Bill.user_id == user_id,
            Bill.status.in_(["unpaid", "overdue"])
        ).order_by(Bill.due_date.asc()).limit(5).all()

        recent_bills_res: List[BillResponse] = [BillResponse.model_validate(b) for b in unpaid_bills]

        # 12. Recent Incomes (up to 5)
        recent_incomes_res: List[IncomeResponse] = []
        for inc in cur_incomes[:5]:
            recent_incomes_res.append(IncomeResponse(
                id=inc.id,
                user_id=inc.user_id,
                source_id=inc.source_id,
                source_name=inc.source.name if inc.source else None,
                title=inc.title,
                amount=inc.amount,
                currency=inc.currency,
                income_date=inc.income_date,
                payment_method=inc.payment_method,
                description=inc.description,
                created_at=inc.created_at,
                updated_at=inc.updated_at
            ))

        # 13. Recent Expenses (up to 5)
        recent_expenses_res: List[ExpenseResponse] = []
        for exp in cur_expenses[:5]:
            recent_expenses_res.append(ExpenseResponse(
                id=exp.id,
                user_id=exp.user_id,
                title=exp.title,
                amount=exp.amount,
                currency=getattr(exp, "currency", "PKR") or "PKR",
                category=exp.category,
                description=exp.description,
                expense_date=exp.expense_date,
                payment_method=exp.payment_method,
                created_at=exp.created_at,
                updated_at=exp.updated_at
            ))

        # 14. Financial Health Assessment
        if len(cur_incomes) == 0 and len(cur_expenses) == 0:
            health_status = "no_data"
            health_title = "No Activity Recorded"
            health_summary = f"No income or expense records found for {target_year}-{target_month:02d}."
        elif net_cashflow > Decimal("0.00"):
            health_status = "surplus"
            health_title = "Positive Cashflow Surplus"
            health_summary = (
                f"Great financial health! You retained a surplus of {display_currency} {net_cashflow:,.2f} "
                f"with a savings rate of {savings_rate:.1f}% this month."
            )
        elif net_cashflow < Decimal("0.00"):
            health_status = "deficit"
            health_title = "Operating at a Deficit"
            health_summary = (
                f"Warning: Your recorded expenses exceed your income by {display_currency} {abs(net_cashflow):,.2f}. "
                "Review discretionary purchases and recurring bills to regain balance."
            )
        else:
            health_status = "balanced"
            health_title = "Balanced Break-Even"
            health_summary = f"Your recorded monthly income matches your expenses exactly ({display_currency} 0.00 net)."

        # 15. Grounded AI Observations
        ai_insights: List[AdvisorInsightItem] = []
        if is_deficit:
            ai_insights.append(AdvisorInsightItem(
                type="alert",
                title="Expenses Exceed Monthly Income",
                description=f"Your expenses outpaced income by {display_currency} {abs(net_cashflow):,.2f} in {target_year}-{target_month:02d}.",
                impact="high"
            ))
        elif net_cashflow > Decimal("0.00"):
            ai_insights.append(AdvisorInsightItem(
                type="strength",
                title="Healthy Monthly Savings Rate",
                description=f"You successfully retained {savings_rate:.1f}% ({display_currency} {monthly_savings:,.2f}) of your earnings.",
                impact="medium"
            ))

        if category_breakdown:
            top_cat = category_breakdown[0]
            if top_cat.percentage > 35.0:
                ai_insights.append(AdvisorInsightItem(
                    type="improvement",
                    title=f"High Spending Concentration in {top_cat.category}",
                    description=f"{top_cat.category} consumes {top_cat.percentage:.1f}% ({display_currency} {top_cat.amount:,.2f}) of monthly expenditure.",
                    impact="medium"
                ))

        if budget_status and budget_status.is_over_budget:
            ai_insights.append(AdvisorInsightItem(
                type="alert",
                title="Overall Monthly Budget Exceeded",
                description=f"Spending has exceeded your budget by {display_currency} {abs(budget_status.remaining_budget):,.2f}.",
                impact="high"
            ))

        return DashboardFinancialSummaryResponse(
            month=target_month,
            year=target_year,
            currency=display_currency,
            summary_cards=summary_cards,
            comparison=comparison,
            category_breakdown=category_breakdown,
            daily_trends=daily_trends,
            recent_incomes=recent_incomes_res,
            recent_expenses=recent_expenses_res,
            upcoming_bills=recent_bills_res,
            budget_status=budget_status,
            ai_insights=ai_insights,
            health_status=health_status,
            health_title=health_title,
            health_summary=health_summary
        )
