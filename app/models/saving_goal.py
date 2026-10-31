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


class SavingGoal(Base):
    """
    SQLAlchemy model for Savings Goals in KharchaAI.
    Tracks user financial goals (e.g. Emergency Fund, Laptop, Hajj, House Down Payment).
    Balances are updated atomically via SavingContribution records.
    """
    __tablename__ = "saving_goals"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    title = Column(String(150), nullable=False)
    description = Column(String(500), nullable=True)
    target_amount = Column(Numeric(12, 2), nullable=False)
    current_amount = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    start_date = Column(Date, nullable=False, default=date.today)
    target_date = Column(Date, nullable=False)
    status = Column(String(20), nullable=False, default="in_progress")  # in_progress, completed, cancelled
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
    user = relationship("User", back_populates="saving_goals")
    contributions = relationship(
        "SavingContribution",
        back_populates="goal",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="SavingContribution.contribution_date.desc()"
    )

    __table_args__ = (
        CheckConstraint("target_amount > 0", name="check_positive_target_amount"),
        CheckConstraint("current_amount >= 0", name="check_non_negative_current_amount"),
        CheckConstraint("status IN ('in_progress', 'completed', 'cancelled')", name="check_valid_goal_status"),
        Index("ix_saving_goals_user_status", "user_id", "status"),
        Index("ix_saving_goals_user_target_date", "user_id", "target_date"),
    )

    @property
    def remaining_amount(self) -> Decimal:
        rem = Decimal(str(self.target_amount)) - Decimal(str(self.current_amount))
        return max(Decimal("0.00"), rem)

    @property
    def progress_percentage(self) -> float:
        if self.target_amount > Decimal("0.00"):
            pct = (float(self.current_amount) / float(self.target_amount)) * 100.0
            return round(min(100.0, pct), 2)
        return 0.0

    def __repr__(self) -> str:
        return f"<SavingGoal id={self.id} user_id={self.user_id} title='{self.title}' target={self.target_amount} current={self.current_amount}>"


class SavingContribution(Base):
    """
    SQLAlchemy model for Savings Contributions / Allocations.
    Represents capital transfers into a designated savings goal (NOT an expense).
    """
    __tablename__ = "saving_contributions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    goal_id = Column(
        Integer,
        ForeignKey("saving_goals.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    amount = Column(Numeric(12, 2), nullable=False)
    contribution_date = Column(Date, nullable=False, default=date.today, index=True)
    notes = Column(String(255), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    goal = relationship("SavingGoal", back_populates="contributions")
    user = relationship("User", back_populates="saving_contributions")

    __table_args__ = (
        CheckConstraint("amount > 0", name="check_positive_contribution_amount"),
        Index("ix_contributions_goal_date", "goal_id", "contribution_date"),
        Index("ix_contributions_user_date", "user_id", "contribution_date"),
    )

    def __repr__(self) -> str:
        return f"<SavingContribution id={self.id} goal_id={self.goal_id} amount={self.amount} date={self.contribution_date}>"
