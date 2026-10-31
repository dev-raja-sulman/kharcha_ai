from calendar import monthrange
from datetime import date, timedelta
from decimal import Decimal
import logging
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models.bill import Bill
from app.models.expense import Expense
from app.schemas.bill import BillCreate, BillResponse, BillSummaryResponse, BillUpdate, MarkPaidRequest

logger = logging.getLogger(__name__)


class BillService:
    """
    Business logic for Bills Management and payment tracking in KharchaAI.
    Safely connects paid bills to expense records while preventing double-counting.
    """

    @classmethod
    def _to_bill_response(cls, b: Bill) -> BillResponse:
        return BillResponse(
            id=b.id,
            user_id=b.user_id,
            title=b.title,
            category=b.category,
            amount=b.amount,
            due_date=b.due_date,
            status=b.status,
            frequency=b.frequency,
            reminder_enabled=b.reminder_enabled,
            paid_date=b.paid_date,
            linked_expense_id=b.linked_expense_id,
            is_overdue=b.is_overdue,
            created_at=b.created_at,
            updated_at=b.updated_at
        )

    @classmethod
    def create_bill(cls, db: Session, user_id: int, bill_in: BillCreate) -> Bill:
        """
        Creates a new bill entry for tracking.
        """
        status_val = "unpaid"
        if bill_in.due_date < date.today():
            status_val = "overdue"

        new_bill = Bill(
            user_id=user_id,
            title=bill_in.title.strip(),
            category=bill_in.category,
            amount=bill_in.amount,
            due_date=bill_in.due_date,
            status=status_val,
            frequency=bill_in.frequency,
            reminder_enabled=bill_in.reminder_enabled
        )
        db.add(new_bill)
        db.commit()
        db.refresh(new_bill)
        return new_bill

    @classmethod
    def get_bills(
        cls,
        db: Session,
        user_id: int,
        status_filter: Optional[str] = None,
        category: Optional[str] = None
    ) -> Tuple[List[Bill], Decimal]:
        """
        Retrieves user's bills with overdue status evaluation.
        """
        today = date.today()

        # Update any unpaid past bills to overdue
        unpaid_past = db.query(Bill).filter(
            Bill.user_id == user_id,
            Bill.status == "unpaid",
            Bill.due_date < today
        ).all()
        for b in unpaid_past:
            b.status = "overdue"
        if unpaid_past:
            db.commit()

        query = db.query(Bill).filter(Bill.user_id == user_id)
        if status_filter:
            query = query.filter(Bill.status == status_filter)
        if category:
            query = query.filter(Bill.category == category)

        bills = query.order_by(Bill.due_date.asc(), Bill.id.desc()).all()
        total_amount = sum((Decimal(str(b.amount)) for b in bills), Decimal("0.00"))
        return bills, total_amount

    @classmethod
    def get_upcoming_bills(cls, db: Session, user_id: int, days: int = 14) -> List[Bill]:
        """
        Retrieves unpaid bills due within the next N days.
        """
        today = date.today()
        cutoff = today + timedelta(days=days)

        return db.query(Bill).filter(
            Bill.user_id == user_id,
            Bill.status.in_(["unpaid", "overdue"]),
            Bill.due_date <= cutoff
        ).order_by(Bill.due_date.asc()).all()

    @classmethod
    def get_bill_by_id(cls, db: Session, user_id: int, bill_id: int) -> Bill:
        """
        Retrieves a single bill by ID ensuring multi-user isolation.
        """
        bill = db.query(Bill).filter(Bill.id == bill_id, Bill.user_id == user_id).first()
        if not bill:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Bill with id {bill_id} not found."
            )
        return bill

    @classmethod
    def update_bill(cls, db: Session, user_id: int, bill_id: int, bill_in: BillUpdate) -> Bill:
        """
        Updates an existing bill.
        """
        bill = cls.get_bill_by_id(db, user_id, bill_id)
        update_data = bill_in.model_dump(exclude_unset=True)

        for key, value in update_data.items():
            setattr(bill, key, value)

        # Re-evaluate overdue if due_date changed and still unpaid
        if bill.status == "unpaid" and bill.due_date < date.today():
            bill.status = "overdue"

        db.commit()
        db.refresh(bill)
        return bill

    @classmethod
    def delete_bill(cls, db: Session, user_id: int, bill_id: int) -> None:
        """
        Deletes a bill record.
        """
        bill = cls.get_bill_by_id(db, user_id, bill_id)
        db.delete(bill)
        db.commit()

    @classmethod
    def mark_as_paid(
        cls,
        db: Session,
        user_id: int,
        bill_id: int,
        req: MarkPaidRequest
    ) -> Bill:
        """
        Marks a bill as paid.
        If create_expense is True, automatically generates an Expense record
        linked to this bill, avoiding double-counting in ledger calculations.
        """
        bill = cls.get_bill_by_id(db, user_id, bill_id)

        if bill.status == "paid":
            return bill

        paid_d = req.paid_date if req.paid_date else date.today()
        bill.status = "paid"
        bill.paid_date = paid_d

        if req.create_expense:
            expense_category = "Bills"
            expense_title = f"Bill: {bill.title}"
            desc = f"Paid {bill.category} bill for PKR {bill.amount:,.2f}"

            new_expense = Expense(
                user_id=user_id,
                title=expense_title,
                amount=bill.amount,
                category=expense_category,
                description=desc,
                expense_date=paid_d,
                payment_method=req.payment_method
            )
            db.add(new_expense)
            db.flush()  # obtain new_expense.id before committing

            bill.linked_expense_id = new_expense.id

        db.commit()
        db.refresh(bill)
        return bill

    @classmethod
    def get_summary(cls, db: Session, user_id: int) -> BillSummaryResponse:
        """
        Computes summary metrics: pending amounts, overdue obligations, and paid bills for current month.
        """
        today = date.today()
        _, last_day = monthrange(today.year, today.month)
        month_start = date(today.year, today.month, 1)
        month_end = date(today.year, today.month, last_day)

        # Update overdue
        unpaid_past = db.query(Bill).filter(
            Bill.user_id == user_id,
            Bill.status == "unpaid",
            Bill.due_date < today
        ).all()
        for b in unpaid_past:
            b.status = "overdue"
        if unpaid_past:
            db.commit()

        # Pending
        pending_bills = db.query(Bill).filter(Bill.user_id == user_id, Bill.status == "unpaid").all()
        pending_total = sum((Decimal(str(b.amount)) for b in pending_bills), Decimal("0.00"))

        # Overdue
        overdue_bills = db.query(Bill).filter(Bill.user_id == user_id, Bill.status == "overdue").all()
        overdue_total = sum((Decimal(str(b.amount)) for b in overdue_bills), Decimal("0.00"))

        # Paid this month
        paid_bills = db.query(Bill).filter(
            Bill.user_id == user_id,
            Bill.status == "paid",
            Bill.paid_date >= month_start,
            Bill.paid_date <= month_end
        ).all()
        paid_total = sum((Decimal(str(b.amount)) for b in paid_bills), Decimal("0.00"))

        # Upcoming in next 14 days
        upcoming = cls.get_upcoming_bills(db, user_id, days=14)

        return BillSummaryResponse(
            total_pending_amount=pending_total,
            pending_count=len(pending_bills),
            total_overdue_amount=overdue_total,
            overdue_count=len(overdue_bills),
            total_paid_this_month=paid_total,
            paid_count_this_month=len(paid_bills),
            upcoming_bills=[cls._to_bill_response(b) for b in upcoming]
        )
