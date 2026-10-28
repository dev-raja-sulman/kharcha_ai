import calendar
from datetime import date, timedelta
from decimal import Decimal
from typing import List, Optional, Tuple
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.budget import Budget
from app.models.expense import Expense
from app.schemas.analytics import (
    BudgetVsActual,
    CategorySpendingPoint,
    DailySpendingPoint,
    MonthComparison,
    SpendingAnalyticsResponse,
    WeeklySpendingPoint,
)


class AnalyticsService:
    """
    Computes real-time personal finance aggregations, time-series trends,
    and month-over-month comparisons from authenticated user expenses.
    """

    @classmethod
    def _get_month_bounds(cls, year: int, month: int) -> Tuple[date, date, int]:
        num_days = calendar.monthrange(year, month)[1]
        return date(year, month, 1), date(year, month, num_days), num_days

    @classmethod
    def _get_previous_month_bounds(cls, year: int, month: int) -> Tuple[date, date, int, int]:
        if month == 1:
            prev_m = 12
            prev_y = year - 1
        else:
            prev_m = month - 1
            prev_y = year
        num_days = calendar.monthrange(prev_y, prev_m)[1]
        return date(prev_y, prev_m, 1), date(prev_y, prev_m, num_days), prev_m, prev_y

    @classmethod
    def get_spending_analytics(
        cls,
        db: Session,
        user_id: int,
        month: Optional[int] = None,
        year: Optional[int] = None
    ) -> SpendingAnalyticsResponse:
        today = date.today()
        target_m = month or today.month
        target_y = year or today.year

        start_date, end_date, total_days = cls._get_month_bounds(target_y, target_m)
        prev_start, prev_end, prev_m, prev_y = cls._get_previous_month_bounds(target_y, target_m)

        # 1. Total spent & transaction count
        total_spent_val = db.query(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= start_date,
            Expense.expense_date <= end_date
        ).scalar() or Decimal("0.00")
        total_spent = Decimal(str(total_spent_val)).quantize(Decimal("0.01"))

        total_tx = db.query(func.count(Expense.id)).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= start_date,
            Expense.expense_date <= end_date
        ).scalar() or 0

        # Average daily spending
        # If calculating for current month, divide by elapsed days; otherwise full month days
        if target_y == today.year and target_m == today.month:
            days_divisor = max(1, today.day)
        else:
            days_divisor = total_days
        avg_daily = (total_spent / Decimal(str(days_divisor))).quantize(Decimal("0.01"))

        # 2. Category Breakdown
        cat_rows = db.query(
            Expense.category,
            func.sum(Expense.amount).label("cat_total"),
            func.count(Expense.id).label("cat_count")
        ).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= start_date,
            Expense.expense_date <= end_date
        ).group_by(Expense.category).order_by(func.sum(Expense.amount).desc()).all()

        category_breakdown = []
        for cat_name, cat_total_raw, cat_count in cat_rows:
            cat_amt = Decimal(str(cat_total_raw)).quantize(Decimal("0.01"))
            pct = float((cat_amt / total_spent) * 100) if total_spent > 0 else 0.0
            category_breakdown.append(CategorySpendingPoint(
                category=cat_name,
                amount=cat_amt,
                percentage=round(pct, 2),
                count=cat_count
            ))

        highest_cat = category_breakdown[0] if category_breakdown else None

        # 3. Daily Spending Points
        daily_rows = db.query(
            Expense.expense_date,
            func.sum(Expense.amount).label("day_total")
        ).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= start_date,
            Expense.expense_date <= end_date
        ).group_by(Expense.expense_date).order_by(Expense.expense_date.asc()).all()

        daily_spending = [
            DailySpendingPoint(
                date=d_date,
                amount=Decimal(str(d_amt)).quantize(Decimal("0.01")),
                day_name=d_date.strftime("%a")
            )
            for d_date, d_amt in daily_rows
        ]

        # 4. Weekly Spending Points
        # Split month into 4 weeks: 1-7, 8-14, 15-21, 22-end
        week_ranges = [
            ("Week 1", date(target_y, target_m, 1), date(target_y, target_m, 7)),
            ("Week 2", date(target_y, target_m, 8), date(target_y, target_m, 14)),
            ("Week 3", date(target_y, target_m, 15), date(target_y, target_m, 21)),
            ("Week 4", date(target_y, target_m, 22), end_date),
        ]

        weekly_spending = []
        for label, w_start, w_end in week_ranges:
            w_total_raw = db.query(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).filter(
                Expense.user_id == user_id,
                Expense.expense_date >= w_start,
                Expense.expense_date <= w_end
            ).scalar() or Decimal("0.00")
            weekly_spending.append(WeeklySpendingPoint(
                week_label=label,
                start_date=w_start,
                end_date=w_end,
                amount=Decimal(str(w_total_raw)).quantize(Decimal("0.01"))
            ))

        # 5. Month-over-Month Comparison
        prev_spent_raw = db.query(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= prev_start,
            Expense.expense_date <= prev_end
        ).scalar() or Decimal("0.00")
        prev_spent = Decimal(str(prev_spent_raw)).quantize(Decimal("0.01"))

        diff = (total_spent - prev_spent).quantize(Decimal("0.01"))
        if prev_spent > Decimal("0.00"):
            pct_change = round(float((diff / prev_spent) * 100), 2)
            trend = "increased" if diff > 0 else ("decreased" if diff < 0 else "unchanged")
        else:
            pct_change = 0.0
            trend = "no_previous_data" if total_spent == 0 else "increased"

        month_comparison = MonthComparison(
            current_month_total=total_spent,
            previous_month_total=prev_spent,
            difference=diff,
            percentage_change=pct_change,
            trend=trend
        )

        # 6. Budget vs Actual
        budgets = db.query(Budget).filter(
            Budget.user_id == user_id,
            Budget.year == target_y,
            Budget.month == target_m
        ).all()

        budget_vs_actual = None
        if budgets:
            overall_b = next((b for b in budgets if b.category is None), None)
            if overall_b:
                tot_budgeted = overall_b.amount
            else:
                tot_budgeted = sum((b.amount for b in budgets), Decimal("0.00"))
            
            tot_budgeted = Decimal(str(tot_budgeted)).quantize(Decimal("0.01"))
            rem = (tot_budgeted - total_spent).quantize(Decimal("0.01"))
            b_pct = round(float((total_spent / tot_budgeted) * 100), 2) if tot_budgeted > 0 else 0.0

            budget_vs_actual = BudgetVsActual(
                total_budgeted=tot_budgeted,
                total_spent=total_spent,
                remaining=rem,
                percentage_used=b_pct
            )

        return SpendingAnalyticsResponse(
            month=target_m,
            year=target_y,
            total_spent=total_spent,
            total_transactions=total_tx,
            average_daily_spending=avg_daily,
            highest_spending_category=highest_cat,
            category_breakdown=category_breakdown,
            daily_spending=daily_spending,
            weekly_spending=weekly_spending,
            month_comparison=month_comparison,
            budget_vs_actual=budget_vs_actual
        )
