from datetime import date, datetime, timezone
from decimal import Decimal
from sqlalchemy import (
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


class Expense(Base):
    """
    SQLAlchemy Expense model for KharchaAI personal finance tracking.
    Uses Numeric(12, 2) for exact currency amounts (never floating point).
    Multi-tenant isolation enforced via user_id foreign key and composite indexes.
    Compatible with PostgreSQL and SQLite.
    """
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    title = Column(String(150), nullable=False)
    # Stored as Numeric(12, 2) for currency precision up to 9,999,999,999.99
    amount = Column(Numeric(12, 2), nullable=False)
    category = Column(String(50), nullable=False, index=True)
    description = Column(String(500), nullable=True)
    expense_date = Column(
        Date,
        nullable=False,
        default=date.today,
        index=True
    )
    payment_method = Column(String(50), nullable=False, default="Cash")
    recurring_rule_id = Column(
        Integer,
        ForeignKey("recurring_expenses.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    recurring_occurrence_date = Column(Date, nullable=True, index=True)
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
    user = relationship("User", back_populates="expenses")
    recurring_rule = relationship("RecurringExpense", back_populates="expenses")

    # Table Constraints & Composite Indexes
    __table_args__ = (
        CheckConstraint("amount > 0", name="check_positive_expense_amount"),
        Index("ix_expenses_user_date", "user_id", "expense_date"),
        Index("ix_expenses_user_category", "user_id", "category"),
        Index("uq_expenses_recurring_occurrence", "recurring_rule_id", "recurring_occurrence_date", unique=True),
    )

    def __repr__(self) -> str:
        return f"<Expense id={self.id} user_id={self.user_id} title='{self.title}' amount={self.amount} category='{self.category}'>"
