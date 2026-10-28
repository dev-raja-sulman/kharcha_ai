from datetime import date
from decimal import Decimal
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.models.expense import Expense
from app.schemas.expense import (
    CategorySummaryItem,
    ExpenseCreateRequest,
    ExpenseSummaryResponse,
    ExpenseUpdateRequest,
    PaymentMethodSummaryItem,
)


class ExpenseService:
    """
    Business logic and multi-user data isolation service for KharchaAI expenses.
    Every query strictly filters by user_id to enforce tenant isolation.
    """

    @staticmethod
    def create_expense(
        db: Session,
        user_id: int,
        req: ExpenseCreateRequest
    ) -> Expense:
        """
        Create a new expense for the authenticated user.
        Client input for user_id is ignored to prevent privilege escalation.
        """
        expense = Expense(
            user_id=user_id,
            title=req.title,
            amount=req.amount,
            category=req.category,
            description=req.description.strip() if req.description else None,
            expense_date=req.expense_date or date.today(),
            payment_method=req.payment_method or "Cash"
        )
        db.add(expense)
        db.commit()
        db.refresh(expense)
        return expense

    @staticmethod
    def get_user_expenses(
        db: Session,
        user_id: int,
        category: Optional[str] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
        sort_by: str = "date_desc"
    ) -> Tuple[List[Expense], int]:
        """
        Query a paginated list of expenses belonging strictly to the authenticated user.
        """
        query = db.query(Expense).filter(Expense.user_id == user_id)

        if category:
            query = query.filter(func.lower(Expense.category) == category.strip().lower())

        if start_date:
            query = query.filter(Expense.expense_date >= start_date)

        if end_date:
            query = query.filter(Expense.expense_date <= end_date)

        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    Expense.title.ilike(term),
                    Expense.description.ilike(term)
                )
            )

        total_count = query.count()

        # Sorting logic
        if sort_by == "date_asc":
            query = query.order_by(Expense.expense_date.asc(), Expense.id.asc())
        elif sort_by == "amount_desc":
            query = query.order_by(Expense.amount.desc(), Expense.id.desc())
        elif sort_by == "amount_asc":
            query = query.order_by(Expense.amount.asc(), Expense.id.asc())
        else:  # default: date_desc
            query = query.order_by(Expense.expense_date.desc(), Expense.id.desc())

        items = query.offset(max(0, skip)).limit(min(100, max(1, limit))).all()
        return items, total_count

    @staticmethod
    def get_expense_by_id(
        db: Session,
        user_id: int,
        expense_id: int
    ) -> Expense:
        """
        Retrieve a single expense by ID, enforcing strict ownership verification.
        Raises 404 if not found or if the expense belongs to another user.
        """
        expense = db.query(Expense).filter(
            Expense.id == expense_id,
            Expense.user_id == user_id
        ).first()

        if not expense:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Expense not found or access denied."
            )
        return expense

    @staticmethod
    def update_expense(
        db: Session,
        user_id: int,
        expense_id: int,
        req: ExpenseUpdateRequest
    ) -> Expense:
        """
        Update an expense belonging to the authenticated user.
        Raises 404 if the expense does not exist or belongs to another user.
        """
        expense = ExpenseService.get_expense_by_id(db, user_id, expense_id)

        update_data = req.model_dump(exclude_unset=True)
        if not update_data:
            return expense

        for field, value in update_data.items():
            if field == "description" and value is not None:
                value = value.strip() or None
            setattr(expense, field, value)

        db.commit()
        db.refresh(expense)
        return expense

    @staticmethod
    def delete_expense(
        db: Session,
        user_id: int,
        expense_id: int
    ) -> None:
        """
        Delete an expense belonging to the authenticated user.
        Raises 404 if the expense does not exist or belongs to another user.
        """
        expense = ExpenseService.get_expense_by_id(db, user_id, expense_id)
        db.delete(expense)
        db.commit()

    @staticmethod
    def get_expense_summary(
        db: Session,
        user_id: int,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None
    ) -> ExpenseSummaryResponse:
        """
        Compute aggregated metrics (totals, category breakdown, payment methods)
        for the authenticated user within the requested date range.
        """
        base_query = db.query(Expense).filter(Expense.user_id == user_id)

        if start_date:
            base_query = base_query.filter(Expense.expense_date >= start_date)
        if end_date:
            base_query = base_query.filter(Expense.expense_date <= end_date)

        # 1. Total amount and count
        total_row = base_query.with_entities(
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("total_sum"),
            func.count(Expense.id).label("total_count")
        ).first()

        total_amount = Decimal(str(total_row[0] or "0.00"))
        total_count = int(total_row[1] or 0)

        # 2. Category breakdown
        category_rows = base_query.with_entities(
            Expense.category,
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("cat_sum"),
            func.count(Expense.id).label("cat_count")
        ).group_by(Expense.category).order_by(func.sum(Expense.amount).desc()).all()

        by_category: List[CategorySummaryItem] = []
        for cat, cat_sum, cat_count in category_rows:
            cat_amount = Decimal(str(cat_sum or "0.00"))
            percentage = float((cat_amount / total_amount) * 100) if total_amount > 0 else 0.0
            by_category.append(CategorySummaryItem(
                category=cat,
                total_amount=cat_amount,
                count=int(cat_count or 0),
                percentage=round(percentage, 2)
            ))

        # 3. Payment method breakdown
        method_rows = base_query.with_entities(
            Expense.payment_method,
            func.coalesce(func.sum(Expense.amount), Decimal("0.00")).label("method_sum"),
            func.count(Expense.id).label("method_count")
        ).group_by(Expense.payment_method).order_by(func.sum(Expense.amount).desc()).all()

        by_payment_method: List[PaymentMethodSummaryItem] = [
            PaymentMethodSummaryItem(
                payment_method=method or "Cash",
                total_amount=Decimal(str(m_sum or "0.00")),
                count=int(m_count or 0)
            )
            for method, m_sum, m_count in method_rows
        ]

        return ExpenseSummaryResponse(
            total_amount=total_amount,
            total_count=total_count,
            by_category=by_category,
            by_payment_method=by_payment_method,
            start_date=start_date,
            end_date=end_date
        )
