from datetime import date, datetime, timezone
from decimal import Decimal
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
)
from sqlalchemy.orm import relationship
from app.db.base import Base


class BillCategory:
    ELECTRICITY = "Electricity"
    GAS = "Gas"
    INTERNET = "Internet"
    MOBILE = "Mobile"
    RENT = "Rent"
    EDUCATION = "Education"
    SUBSCRIPTIONS = "Subscriptions"
    OTHER = "Other"

    @classmethod
    def list_all(cls):
        return [
            cls.ELECTRICITY,
            cls.GAS,
            cls.INTERNET,
            cls.MOBILE,
            cls.RENT,
            cls.EDUCATION,
            cls.SUBSCRIPTIONS,
            cls.OTHER,
        ]


class Bill(Base):
    """
    SQLAlchemy model for Bill Tracking in KharchaAI.
    Manages upcoming utility, rent, and subscription obligations.
    Separate from expenses; when paid, can optionally link to an expense to avoid double counting.
    """
    __tablename__ = "bills"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    title = Column(String(150), nullable=False)
    category = Column(String(50), nullable=False, default="Other")
    amount = Column(Numeric(12, 2), nullable=False)
    due_date = Column(Date, nullable=False, index=True)
    status = Column(String(20), nullable=False, default="unpaid", index=True)  # unpaid, paid, overdue
    frequency = Column(String(20), nullable=False, default="one_time")  # one_time, monthly, quarterly, yearly
    reminder_enabled = Column(Boolean, nullable=False, default=True)
    paid_date = Column(Date, nullable=True)
    linked_expense_id = Column(
        Integer,
        ForeignKey("expenses.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    user = relationship("User", back_populates="bills")
    linked_expense = relationship("Expense", foreign_keys=[linked_expense_id])

    __table_args__ = (
        CheckConstraint("amount > 0", name="check_positive_bill_amount"),
        CheckConstraint("status IN ('unpaid', 'paid', 'overdue')", name="check_valid_bill_status"),
        CheckConstraint("frequency IN ('one_time', 'monthly', 'quarterly', 'yearly')", name="check_valid_bill_frequency"),
        Index("ix_bills_user_status", "user_id", "status"),
        Index("ix_bills_user_due_date", "user_id", "due_date"),
    )

    @property
    def is_overdue(self) -> bool:
        if self.status != "paid" and self.due_date < date.today():
            return True
        return False

    def __repr__(self) -> str:
        return f"<Bill id={self.id} user_id={self.user_id} title='{self.title}' amount={self.amount} due={self.due_date} status='{self.status}'>"
