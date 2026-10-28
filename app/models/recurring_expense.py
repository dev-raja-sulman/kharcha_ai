from datetime import date, datetime, timezone
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


class RecurringExpense(Base):
    """
    SQLAlchemy model for Recurring Expense rules in KharchaAI.
    Defines automation rules for generating recurring expenses (Daily, Weekly, Monthly, Yearly).
    Expenses created by these rules reference recurring_rule_id.
    """
    __tablename__ = "recurring_expenses"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    title = Column(String(150), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    category = Column(String(50), nullable=False, index=True)
    description = Column(String(500), nullable=True)
    frequency = Column(String(20), nullable=False, index=True)  # daily, weekly, monthly, yearly
    payment_method = Column(String(50), nullable=False, default="Cash")
    start_date = Column(Date, nullable=False, default=date.today)
    end_date = Column(Date, nullable=True)
    next_scheduled_date = Column(Date, nullable=False, index=True)
    last_generated_date = Column(Date, nullable=True)
    status = Column(String(20), nullable=False, default="active", index=True)  # active, paused, cancelled, completed
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
    user = relationship("User", back_populates="recurring_expenses")
    expenses = relationship(
        "Expense",
        back_populates="recurring_rule",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    __table_args__ = (
        CheckConstraint("amount > 0", name="check_positive_recurring_amount"),
        CheckConstraint(
            "frequency IN ('daily', 'weekly', 'monthly', 'yearly')",
            name="check_valid_recurring_frequency"
        ),
        CheckConstraint(
            "status IN ('active', 'paused', 'cancelled', 'completed')",
            name="check_valid_recurring_status"
        ),
        Index("ix_recurring_user_status", "user_id", "status"),
        Index("ix_recurring_user_next_date", "user_id", "next_scheduled_date"),
    )

    def __repr__(self) -> str:
        return f"<RecurringExpense id={self.id} user_id={self.user_id} title='{self.title}' amount={self.amount} freq='{self.frequency}' status='{self.status}'>"
