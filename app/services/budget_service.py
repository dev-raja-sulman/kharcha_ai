import calendar
from datetime import date
from decimal import Decimal
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app.models.budget import Budget
from app.models.expense import Expense
from app.schemas.budget import (
    BudgetAlertLevel,
    BudgetCreateRequest,
    BudgetListResponse,
    BudgetProgressSummaryResponse,
    BudgetResponse,
    BudgetUpdateRequest,
)


def _get_month_date_range(year: int, month: int) -> Tuple[date, date]:
    """Returns the first and last date of a given month and year."""
    num_days = calendar.monthrange(year, month)[1]
    return date(year, month, 1), date(year, month, num_days)


def _calculate_alert_details(
    spent: Decimal,
    budget_amount: Decimal,
    category: Optional[str]
) -> Tuple[BudgetAlertLevel, str, float]:
    """Determines alert level and user-friendly advisory message."""
    if budget_amount <= Decimal("0.00"):
        return BudgetAlertLevel.NORMAL, "Budget amount is zero.", 0.0

    pct = float((spent / budget_amount) * 100)
    label = f"'{category}'" if category else "overall monthly"

    if pct >= 100.0:
        return (
            BudgetAlertLevel.EXCEEDED_100,
            f"Alert: You have exceeded your {label} budget ({pct:.1f}% used).",
            pct
        )
    elif pct >= 80.0:
        return (
            BudgetAlertLevel.WARNING_80,
            f"Warning: You have reached 80% threshold of your {label} budget ({pct:.1f}% used).",
            pct
        )
    elif pct >= 50.0:
        return (
            BudgetAlertLevel.WARNING_50,
            f"Notice: You have utilized 50% of your {label} budget ({pct:.1f}% used).",
            pct
        )
    return (
        BudgetAlertLevel.NORMAL,
        f"Spending is well within budget limits ({pct:.1f}% used).",
        pct
    )


class BudgetService:
    """
    Service managing budget creation, calculations, threshold alerts,
    and multi-tenant user isolation.
    """

    @classmethod
    def _compute_spent(
        cls,
        db: Session,
        user_id: int,
        start_date: date,
        end_date: date,
        category: Optional[str]
    ) -> Decimal:
        """
        Calculates actual real-time expenses for the user in the budget period.
        If category is None, aggregates all expenses (overall budget).
        """
        query = db.query(func.coalesce(func.sum(Expense.amount), Decimal("0.00"))).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= start_date,
            Expense.expense_date <= end_date
        )

        if category is not None:
            query = query.filter(Expense.category == category)

        val = query.scalar() or Decimal("0.00")
        return Decimal(str(val)).quantize(Decimal("0.01"))

    @classmethod
    def _enrich_budget_response(cls, db: Session, budget: Budget) -> BudgetResponse:
        """Enriches raw DB Budget model with dynamic progress calculations."""
        spent = cls._compute_spent(
            db=db,
            user_id=budget.user_id,
            start_date=budget.start_date,
            end_date=budget.end_date,
            category=budget.category
        )
        remaining = (budget.amount - spent).quantize(Decimal("0.01"))
        alert_lvl, alert_msg, pct = _calculate_alert_details(spent, budget.amount, budget.category)

        return BudgetResponse(
            id=budget.id,
            user_id=budget.user_id,
            name=budget.name,
            amount=budget.amount,
            category=budget.category,
            month=budget.month,
            year=budget.year,
            start_date=budget.start_date,
            end_date=budget.end_date,
            spent=spent,
            remaining=remaining,
            percentage_used=round(pct, 2),
            alert_level=alert_lvl,
            alert_message=alert_msg,
            created_at=budget.created_at,
            updated_at=budget.updated_at
        )

    @classmethod
    def create_budget(
        cls,
        db: Session,
        user_id: int,
        budget_in: BudgetCreateRequest
    ) -> BudgetResponse:
        start_date, end_date = _get_month_date_range(budget_in.year, budget_in.month)

        # Check for duplicate budget for this user, year, month, and category
        existing = db.query(Budget).filter(
            Budget.user_id == user_id,
            Budget.year == budget_in.year,
            Budget.month == budget_in.month
        )

        if budget_in.category is None:
            existing = existing.filter(Budget.category.is_(None))
        else:
            existing = existing.filter(Budget.category == budget_in.category)

        if existing.first():
            cat_desc = f"category '{budget_in.category}'" if budget_in.category else "overall spending"
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"A budget for {cat_desc} already exists for {budget_in.year}-{budget_in.month:02d}."
            )

        budget = Budget(
            user_id=user_id,
            name=budget_in.name,
            amount=budget_in.amount,
            category=budget_in.category,
            month=budget_in.month,
            year=budget_in.year,
            start_date=start_date,
            end_date=end_date
        )
        db.add(budget)
        db.commit()
        db.refresh(budget)

        return cls._enrich_budget_response(db, budget)

    @classmethod
    def get_budgets(
        cls,
        db: Session,
        user_id: int,
        month: Optional[int] = None,
        year: Optional[int] = None
    ) -> BudgetListResponse:
        today = date.today()
        target_month = month or today.month
        target_year = year or today.year

        query = db.query(Budget).filter(
            Budget.user_id == user_id,
            Budget.year == target_year,
            Budget.month == target_month
        ).order_by(Budget.category.asc().nullsfirst(), Budget.created_at.desc())

        items = query.all()
        enriched_items = [cls._enrich_budget_response(db, b) for b in items]

        # Calculate total budgeted and spent
        total_budgeted = sum((b.amount for b in enriched_items), Decimal("0.00")).quantize(Decimal("0.01"))
        # If overall budget exists, use overall spent, else sum category spent
        overall_b = next((b for b in enriched_items if b.category is None), None)
        if overall_b:
            total_spent = overall_b.spent
        else:
            total_spent = sum((b.spent for b in enriched_items), Decimal("0.00")).quantize(Decimal("0.01"))

        pct = float((total_spent / total_budgeted) * 100) if total_budgeted > 0 else 0.0

        return BudgetListResponse(
            total=len(enriched_items),
            items=enriched_items,
            month=target_month,
            year=target_year,
            total_budgeted=total_budgeted,
            total_spent=total_spent,
            overall_percentage=round(pct, 2)
        )

    @classmethod
    def get_budget_by_id(cls, db: Session, budget_id: int, user_id: int) -> BudgetResponse:
        budget = db.query(Budget).filter(
            Budget.id == budget_id,
            Budget.user_id == user_id
        ).first()

        if not budget:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Budget with ID {budget_id} not found."
            )

        return cls._enrich_budget_response(db, budget)

    @classmethod
    def update_budget(
        cls,
        db: Session,
        budget_id: int,
        user_id: int,
        update_in: BudgetUpdateRequest
    ) -> BudgetResponse:
        budget = db.query(Budget).filter(
            Budget.id == budget_id,
            Budget.user_id == user_id
        ).first()

        if not budget:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Budget with ID {budget_id} not found."
            )

        if update_in.name is not None:
            budget.name = update_in.name
        if update_in.amount is not None:
            budget.amount = update_in.amount

        db.commit()
        db.refresh(budget)
        return cls._enrich_budget_response(db, budget)

    @classmethod
    def delete_budget(cls, db: Session, budget_id: int, user_id: int) -> None:
        budget = db.query(Budget).filter(
            Budget.id == budget_id,
            Budget.user_id == user_id
        ).first()

        if not budget:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Budget with ID {budget_id} not found."
            )

        db.delete(budget)
        db.commit()

    @classmethod
    def get_progress_summary(
        cls,
        db: Session,
        user_id: int,
        month: Optional[int] = None,
        year: Optional[int] = None
    ) -> BudgetProgressSummaryResponse:
        today = date.today()
        target_month = month or today.month
        target_year = year or today.year

        list_res = cls.get_budgets(db, user_id, month=target_month, year=target_year)

        overall = next((b for b in list_res.items if b.category is None), None)
        category_budgets = [b for b in list_res.items if b.category is not None]

        active_alerts = []
        for b in list_res.items:
            if b.alert_level != BudgetAlertLevel.NORMAL:
                active_alerts.append({
                    "budget_id": b.id,
                    "budget_name": b.name,
                    "category": b.category or "Overall",
                    "level": b.alert_level.value,
                    "percentage_used": b.percentage_used,
                    "spent": str(b.spent),
                    "amount": str(b.amount),
                    "message": b.alert_message
                })

        return BudgetProgressSummaryResponse(
            month=target_month,
            year=target_year,
            overall_budget=overall,
            category_budgets=category_budgets,
            active_alerts=active_alerts
        )
