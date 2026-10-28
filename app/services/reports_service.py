import calendar
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.expense import Expense
from app.schemas.reports import (
    AdvancedReportResponse,
    CategoryReportItem,
    PeriodComparisonData,
    RecurringVsRegularBreakdown,
    ReportType,
    TrendPoint,
)


class ReportsService:
    """
    Advanced Reporting and Financial Analysis Engine for KharchaAI.
    Generates deterministic, evidence-based reports from authenticated user expense data.
    Enforces user isolation, decimal precision, and accurate period-over-period comparisons.
    """

    @classmethod
    def resolve_date_range(
        cls,
        report_type: ReportType,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        year: Optional[int] = None,
        month: Optional[int] = None,
        as_of_date: Optional[date] = None,
    ) -> Tuple[date, date, date, date]:
        """
        Determines current period (start_date, end_date) and
        equivalent previous period (prev_start_date, prev_end_date).
        """
        today = as_of_date or date.today()

        if report_type == ReportType.DAILY:
            cur_start = start_date or today
            cur_end = cur_start
            prev_end = cur_start - timedelta(days=1)
            prev_start = prev_end

        elif report_type == ReportType.WEEKLY:
            if start_date and end_date:
                cur_start = start_date
                cur_end = end_date
            else:
                # Calendar week: Monday to Sunday
                cur_start = today - timedelta(days=today.weekday())
                cur_end = cur_start + timedelta(days=6)
            duration = (cur_end - cur_start).days + 1
            prev_end = cur_start - timedelta(days=1)
            prev_start = prev_end - timedelta(days=duration - 1)

        elif report_type == ReportType.MONTHLY:
            target_year = year or (start_date.year if start_date else today.year)
            target_month = month or (start_date.month if start_date else today.month)
            max_day = calendar.monthrange(target_year, target_month)[1]
            cur_start = date(target_year, target_month, 1)
            cur_end = date(target_year, target_month, max_day)

            # Previous calendar month
            prev_m = 12 if target_month == 1 else target_month - 1
            prev_y = target_year - 1 if target_month == 1 else target_year
            prev_max_day = calendar.monthrange(prev_y, prev_m)[1]
            prev_start = date(prev_y, prev_m, 1)
            prev_end = date(prev_y, prev_m, prev_max_day)

        elif report_type == ReportType.YEARLY:
            target_year = year or (start_date.year if start_date else today.year)
            cur_start = date(target_year, 1, 1)
            cur_end = date(target_year, 12, 31)
            prev_start = date(target_year - 1, 1, 1)
            prev_end = date(target_year - 1, 12, 31)

        else:  # CUSTOM or CATEGORY
            if not start_date or not end_date:
                cur_start = today.replace(day=1)
                cur_end = today
            else:
                cur_start = start_date
                cur_end = end_date

            if cur_end < cur_start:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Report end date cannot be earlier than start date."
                )

            duration = (cur_end - cur_start).days + 1
            prev_end = cur_start - timedelta(days=1)
            prev_start = prev_end - timedelta(days=duration - 1)

        return cur_start, cur_end, prev_start, prev_end

    @classmethod
    def get_filtered_expenses(
        cls,
        db: Session,
        user_id: int,
        start_date: date,
        end_date: date,
        category: Optional[str] = None
    ) -> List[Expense]:
        """
        Retrieves ordered expense records strictly belonging to the authenticated user.
        """
        query = db.query(Expense).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= start_date,
            Expense.expense_date <= end_date
        )
        if category:
            query = query.filter(func.lower(Expense.category) == category.strip().lower())

        return query.order_by(Expense.expense_date.asc(), Expense.id.asc()).all()

    @classmethod
    def generate_report(
        cls,
        db: Session,
        user_id: int,
        report_type: ReportType = ReportType.MONTHLY,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        year: Optional[int] = None,
        month: Optional[int] = None,
        category: Optional[str] = None
    ) -> AdvancedReportResponse:
        """
        Generates a comprehensive advanced report with financial summaries,
        category distributions, recurring vs regular spending, and trend analysis.
        """
        cur_start, cur_end, prev_start, prev_end = cls.resolve_date_range(
            report_type=report_type,
            start_date=start_date,
            end_date=end_date,
            year=year,
            month=month
        )

        # 1. Fetch current period expenses
        expenses = cls.get_filtered_expenses(
            db=db,
            user_id=user_id,
            start_date=cur_start,
            end_date=cur_end,
            category=category
        )

        total_expenses = len(expenses)
        total_expenditure = sum((Decimal(str(e.amount)) for e in expenses), Decimal("0.00"))

        duration_days = max(1, (cur_end - cur_start).days + 1)
        average_daily = Decimal(str(round(total_expenditure / Decimal(duration_days), 2)))

        # 2. Category Breakdown
        cat_map = {}
        for exp in expenses:
            c = exp.category
            if c not in cat_map:
                cat_map[c] = {"amount": Decimal("0.00"), "count": 0}
            cat_map[c]["amount"] += Decimal(str(exp.amount))
            cat_map[c]["count"] += 1

        category_breakdown: List[CategoryReportItem] = []
        for cat_name, data in cat_map.items():
            pct = float(round((data["amount"] / total_expenditure * Decimal(100)), 2)) if total_expenditure > 0 else 0.0
            category_breakdown.append(
                CategoryReportItem(
                    category=cat_name,
                    total_amount=data["amount"],
                    percentage=pct,
                    count=data["count"]
                )
            )
        category_breakdown.sort(key=lambda x: x.total_amount, reverse=True)

        highest_cat = category_breakdown[0] if category_breakdown else None

        # 3. Recurring vs Regular Breakdown
        recurring_amount = Decimal("0.00")
        recurring_count = 0
        regular_amount = Decimal("0.00")
        regular_count = 0

        for exp in expenses:
            amt = Decimal(str(exp.amount))
            if exp.recurring_rule_id is not None:
                recurring_amount += amt
                recurring_count += 1
            else:
                regular_amount += amt
                regular_count += 1

        rec_pct = float(round((recurring_amount / total_expenditure * Decimal(100)), 2)) if total_expenditure > 0 else 0.0
        reg_pct = float(round((regular_amount / total_expenditure * Decimal(100)), 2)) if total_expenditure > 0 else 0.0

        recurring_vs_regular = RecurringVsRegularBreakdown(
            recurring_amount=recurring_amount,
            recurring_count=recurring_count,
            recurring_percentage=rec_pct,
            regular_amount=regular_amount,
            regular_count=regular_count,
            regular_percentage=reg_pct
        )

        # 4. Spending Trends
        spending_trends: List[TrendPoint] = []
        if duration_days <= 31:
            # Daily trends
            day_map = {cur_start + timedelta(days=i): {"amount": Decimal("0.00"), "count": 0} for i in range(duration_days)}
            for exp in expenses:
                if exp.expense_date in day_map:
                    day_map[exp.expense_date]["amount"] += Decimal(str(exp.amount))
                    day_map[exp.expense_date]["count"] += 1

            for d, data in sorted(day_map.items()):
                spending_trends.append(
                    TrendPoint(
                        label=d.strftime("%b %d"),
                        point_date=d,
                        amount=data["amount"],
                        count=data["count"]
                    )
                )
        else:
            # Monthly aggregated trends
            month_map = {}
            for exp in expenses:
                m_key = exp.expense_date.strftime("%Y-%m")
                m_label = exp.expense_date.strftime("%b %Y")
                if m_key not in month_map:
                    month_map[m_key] = {
                        "label": m_label,
                        "point_date": exp.expense_date.replace(day=1),
                        "amount": Decimal("0.00"),
                        "count": 0
                    }
                month_map[m_key]["amount"] += Decimal(str(exp.amount))
                month_map[m_key]["count"] += 1

            for k in sorted(month_map.keys()):
                d = month_map[k]
                spending_trends.append(
                    TrendPoint(
                        label=d["label"],
                        point_date=d["point_date"],
                        amount=d["amount"],
                        count=d["count"]
                    )
                )

        # 5. Period Comparison
        prev_expenses = cls.get_filtered_expenses(
            db=db,
            user_id=user_id,
            start_date=prev_start,
            end_date=prev_end,
            category=category
        )
        prev_expenditure = sum((Decimal(str(e.amount)) for e in prev_expenses), Decimal("0.00"))
        prev_count = len(prev_expenses)

        diff = total_expenditure - prev_expenditure
        if prev_expenditure > 0:
            pct_change = float(round((diff / prev_expenditure) * Decimal(100), 2))
            trend_str = "increased" if diff > 0 else ("decreased" if diff < 0 else "unchanged")
        elif total_expenditure > 0:
            pct_change = 100.0
            trend_str = "increased"
        else:
            pct_change = 0.0
            trend_str = "no_previous_data" if prev_count == 0 else "unchanged"

        period_comp = PeriodComparisonData(
            previous_start_date=prev_start,
            previous_end_date=prev_end,
            previous_expenditure=prev_expenditure,
            previous_count=prev_count,
            difference=diff,
            percentage_change=pct_change,
            trend=trend_str
        )

        return AdvancedReportResponse(
            report_type=report_type.value,
            start_date=cur_start,
            end_date=cur_end,
            total_expenditure=total_expenditure,
            total_expenses=total_expenses,
            average_daily_spending=average_daily,
            highest_spending_category=highest_cat,
            category_breakdown=category_breakdown,
            spending_trends=spending_trends,
            recurring_vs_regular=recurring_vs_regular,
            period_comparison=period_comp,
            generated_at=datetime.now(timezone.utc).isoformat()
        )
