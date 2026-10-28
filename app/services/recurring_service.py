import calendar
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.expense import Expense
from app.models.recurring_expense import RecurringExpense
from app.schemas.recurring import (
    RecurringExpenseCreateRequest,
    RecurringExpenseUpdateRequest,
    RecurringFrequency,
    RecurringStatus,
)


class RecurringService:
    """
    Business logic and lifecycle management service for Recurring Expenses in KharchaAI.
    Ensures multi-tenant isolation, idempotent expense generation, and decimal precision.
    """

    @staticmethod
    def calculate_next_date(current_date: date, frequency: str) -> date:
        """
        Calculates the next occurrence date according to frequency.
        Handles calendar month-end clamping (e.g. Jan 31 -> Feb 28/29) and leap years safely.
        """
        freq = frequency.lower()
        if freq == RecurringFrequency.DAILY.value:
            return current_date + timedelta(days=1)
        elif freq == RecurringFrequency.WEEKLY.value:
            return current_date + timedelta(days=7)
        elif freq == RecurringFrequency.MONTHLY.value:
            new_month = 1 if current_date.month == 12 else current_date.month + 1
            new_year = current_date.year + 1 if current_date.month == 12 else current_date.year
            max_day = calendar.monthrange(new_year, new_month)[1]
            return date(new_year, new_month, min(current_date.day, max_day))
        elif freq == RecurringFrequency.YEARLY.value:
            new_year = current_date.year + 1
            max_day = calendar.monthrange(new_year, current_date.month)[1]
            return date(new_year, current_date.month, min(current_date.day, max_day))
        else:
            raise ValueError(f"Unsupported recurring frequency: {frequency}")

    @classmethod
    def create_rule(
        cls,
        db: Session,
        user_id: int,
        req: RecurringExpenseCreateRequest
    ) -> RecurringExpense:
        """
        Creates a new recurring expense rule for the authenticated user.
        Validates frequency, dates, and amounts.
        """
        start_dt = req.start_date or date.today()

        if req.end_date and req.end_date < start_dt:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="End date cannot be earlier than start date."
            )

        rule = RecurringExpense(
            user_id=user_id,
            title=req.title,
            amount=req.amount,
            category=req.category,
            description=req.description.strip() if req.description else None,
            frequency=req.frequency.value,
            payment_method=req.payment_method or "Cash",
            start_date=start_dt,
            end_date=req.end_date,
            next_scheduled_date=start_dt,
            status=RecurringStatus.ACTIVE.value
        )
        db.add(rule)
        db.commit()
        db.refresh(rule)
        return rule

    @classmethod
    def get_user_rules(
        cls,
        db: Session,
        user_id: int,
        status_filter: Optional[str] = None
    ) -> List[RecurringExpense]:
        """
        Retrieves recurring rules strictly belonging to the authenticated user.
        """
        query = db.query(RecurringExpense).filter(RecurringExpense.user_id == user_id)
        if status_filter:
            query = query.filter(RecurringExpense.status == status_filter.lower())
        return query.order_by(RecurringExpense.next_scheduled_date.asc(), RecurringExpense.id.desc()).all()

    @classmethod
    def get_rule_by_id(
        cls,
        db: Session,
        user_id: int,
        rule_id: int
    ) -> RecurringExpense:
        """
        Retrieves a single recurring rule ensuring multi-user tenant isolation.
        """
        rule = db.query(RecurringExpense).filter(
            RecurringExpense.id == rule_id,
            RecurringExpense.user_id == user_id
        ).first()
        if not rule:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Recurring expense rule with id {rule_id} not found."
            )
        return rule

    @classmethod
    def update_rule(
        cls,
        db: Session,
        user_id: int,
        rule_id: int,
        req: RecurringExpenseUpdateRequest
    ) -> RecurringExpense:
        """
        Updates an existing recurring expense rule.
        """
        rule = cls.get_rule_by_id(db, user_id, rule_id)

        if req.title is not None:
            rule.title = req.title
        if req.amount is not None:
            rule.amount = req.amount
        if req.category is not None:
            rule.category = req.category
        if req.description is not None:
            rule.description = req.description.strip() if req.description else None
        if req.payment_method is not None:
            rule.payment_method = req.payment_method
        if req.frequency is not None:
            rule.frequency = req.frequency.value
            # Recalculate next scheduled date if frequency changed
            if rule.next_scheduled_date < date.today():
                rule.next_scheduled_date = date.today()
        if req.end_date is not None:
            if req.end_date < rule.start_date:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="End date cannot be earlier than start date."
                )
            rule.end_date = req.end_date

        rule.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(rule)
        return rule

    @classmethod
    def pause_rule(cls, db: Session, user_id: int, rule_id: int) -> RecurringExpense:
        """
        Pauses an active recurring rule.
        """
        rule = cls.get_rule_by_id(db, user_id, rule_id)
        if rule.status == RecurringStatus.CANCELLED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot pause a cancelled recurring rule."
            )
        rule.status = RecurringStatus.PAUSED.value
        rule.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(rule)
        return rule

    @classmethod
    def resume_rule(cls, db: Session, user_id: int, rule_id: int) -> RecurringExpense:
        """
        Resumes a paused recurring rule.
        """
        rule = cls.get_rule_by_id(db, user_id, rule_id)
        if rule.status == RecurringStatus.CANCELLED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot resume a cancelled recurring rule."
            )
        if rule.end_date and rule.end_date < date.today():
            rule.status = RecurringStatus.COMPLETED.value
            db.commit()
            db.refresh(rule)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot resume rule because its end date has already passed."
            )
        rule.status = RecurringStatus.ACTIVE.value
        rule.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(rule)
        return rule

    @classmethod
    def cancel_rule(cls, db: Session, user_id: int, rule_id: int) -> RecurringExpense:
        """
        Cancels a recurring rule so no further expenses will be generated.
        Historical expenses generated by this rule are preserved.
        """
        rule = cls.get_rule_by_id(db, user_id, rule_id)
        rule.status = RecurringStatus.CANCELLED.value
        rule.updated_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(rule)
        return rule

    @classmethod
    def get_rule_history(
        cls,
        db: Session,
        user_id: int,
        rule_id: int
    ) -> List[Expense]:
        """
        Retrieves all expenses created by this recurring rule, ordered by date descending.
        """
        cls.get_rule_by_id(db, user_id, rule_id)  # Enforce ownership check
        return db.query(Expense).filter(
            Expense.user_id == user_id,
            Expense.recurring_rule_id == rule_id
        ).order_by(Expense.expense_date.desc(), Expense.id.desc()).all()

    @classmethod
    def process_due_expenses(
        cls,
        db: Session,
        user_id: Optional[int] = None,
        as_of_date: Optional[date] = None
    ) -> Tuple[int, int]:
        """
        Idempotent engine for generating due recurring expenses.
        Processes active recurring rules where next_scheduled_date <= as_of_date.
        Prevents duplicate creation through database uniqueness constraints and checks.
        Returns: (processed_rules_count, generated_expenses_count)
        """
        target_date = as_of_date or date.today()

        query = db.query(RecurringExpense).filter(
            RecurringExpense.status == RecurringStatus.ACTIVE.value,
            RecurringExpense.next_scheduled_date <= target_date
        )
        if user_id is not None:
            query = query.filter(RecurringExpense.user_id == user_id)

        due_rules = query.all()
        generated_count = 0
        processed_rules = len(due_rules)

        for rule in due_rules:
            # Advance occurrences up to target_date
            while rule.status == RecurringStatus.ACTIVE.value and rule.next_scheduled_date <= target_date:
                occurrence_date = rule.next_scheduled_date

                # Verify end date boundary
                if rule.end_date and occurrence_date > rule.end_date:
                    rule.status = RecurringStatus.COMPLETED.value
                    break

                # Idempotency check: verify expense not already created for this rule & occurrence
                existing = db.query(Expense).filter(
                    Expense.recurring_rule_id == rule.id,
                    Expense.recurring_occurrence_date == occurrence_date
                ).first()

                if not existing:
                    note = rule.description or ""
                    recurring_suffix = f"[Recurring {rule.frequency.title()}]"
                    full_desc = f"{note} {recurring_suffix}".strip() if note else recurring_suffix

                    expense = Expense(
                        user_id=rule.user_id,
                        title=rule.title,
                        amount=rule.amount,
                        category=rule.category,
                        description=full_desc,
                        expense_date=occurrence_date,
                        payment_method=rule.payment_method,
                        recurring_rule_id=rule.id,
                        recurring_occurrence_date=occurrence_date
                    )
                    db.add(expense)
                    generated_count += 1

                rule.last_generated_date = occurrence_date
                next_date = cls.calculate_next_date(occurrence_date, rule.frequency)

                # Check if next date exceeds end date
                if rule.end_date and next_date > rule.end_date:
                    rule.status = RecurringStatus.COMPLETED.value

                rule.next_scheduled_date = next_date
                rule.updated_at = datetime.now(timezone.utc)

        db.commit()
        return processed_rules, generated_count
