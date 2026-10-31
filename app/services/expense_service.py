from datetime import date
from decimal import Decimal
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.models.expense import Expense
from app.models.user import User
from app.schemas.expense import (
    CategorySummaryItem,
    ExpenseCreateRequest,
    ExpenseSummaryResponse,
    ExpenseUpdateRequest,
    PaymentMethodSummaryItem,
)
from app.services.exchange_rate_service import ExchangeRateService


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
            currency=(req.currency or "PKR").upper().strip(),
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
            elif field == "currency" and value is not None:
                value = value.upper().strip()
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
        end_date: Optional[date] = None,
        target_currency: Optional[str] = None
    ) -> ExpenseSummaryResponse:
        """
        Compute aggregated metrics (totals, category breakdown, payment methods)
        for the authenticated user within the requested date range.
        Converts expenses to target_currency using stored exchange rates without mixing currencies directly.
        """
        user = db.query(User).filter(User.id == user_id).first()
        display_curr = (
            target_currency.strip().upper()
            if target_currency
            else (user.preferred_currency if user and user.preferred_currency else "PKR")
        )

        base_query = db.query(Expense).filter(Expense.user_id == user_id)

        if start_date:
            base_query = base_query.filter(Expense.expense_date >= start_date)
        if end_date:
            base_query = base_query.filter(Expense.expense_date <= end_date)

        expenses = base_query.all()
        total_count = len(expenses)

        total_amount = Decimal("0.00")
        by_currency: dict = {}
        category_map: dict = {}
        payment_map: dict = {}

        for exp in expenses:
            amt = Decimal(str(exp.amount))
            curr = (exp.currency or "PKR").upper().strip()
            by_currency[curr] = by_currency.get(curr, Decimal("0.00")) + amt

            if curr == display_curr:
                conv_amt = amt
            else:
                converted = ExchangeRateService.convert(
                    db=db,
                    amount=amt,
                    from_currency=curr,
                    to_currency=display_curr,
                    effective_on=exp.expense_date
                )
                conv_amt = converted if converted is not None else Decimal("0.00")

            total_amount += conv_amt

            # Category aggregation
            cat = exp.category
            if cat not in category_map:
                category_map[cat] = {"amount": Decimal("0.00"), "count": 0}
            category_map[cat]["amount"] += conv_amt
            category_map[cat]["count"] += 1

            # Payment method aggregation
            pm = exp.payment_method or "Cash"
            if pm not in payment_map:
                payment_map[pm] = {"amount": Decimal("0.00"), "count": 0}
            payment_map[pm]["amount"] += conv_amt
            payment_map[pm]["count"] += 1

        by_category: List[CategorySummaryItem] = []
        for cat, data in sorted(category_map.items(), key=lambda x: x[1]["amount"], reverse=True):
            pct = float((data["amount"] / total_amount) * 100) if total_amount > 0 else 0.0
            by_category.append(CategorySummaryItem(
                category=cat,
                total_amount=data["amount"],
                count=data["count"],
                percentage=round(pct, 2)
            ))

        by_payment_method: List[PaymentMethodSummaryItem] = [
            PaymentMethodSummaryItem(
                payment_method=pm,
                total_amount=data["amount"],
                count=data["count"]
            )
            for pm, data in sorted(payment_map.items(), key=lambda x: x[1]["amount"], reverse=True)
        ]

        by_currency_serialized = {k: float(v) for k, v in by_currency.items()}

        return ExpenseSummaryResponse(
            currency=display_curr,
            total_amount=total_amount,
            total_count=total_count,
            by_category=by_category,
            by_payment_method=by_payment_method,
            by_currency=by_currency_serialized,
            start_date=start_date,
            end_date=end_date
        )
