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


class Budget(Base):
    """
    SQLAlchemy model for monthly budget tracking.
    Supports both overall monthly budgets (category=None) and
    category-specific budgets (e.g. Food, Transport, etc.).
    """
    __tablename__ = "budgets"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    name = Column(String(100), nullable=False)
    # Stored as Numeric(12, 2) for exact currency precision
    amount = Column(Numeric(12, 2), nullable=False)
    category = Column(String(50), nullable=True, index=True)
    month = Column(Integer, nullable=False)  # 1 - 12
    year = Column(Integer, nullable=False)   # e.g. 2026
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
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

    # Relationship to user
    user = relationship("User", back_populates="budgets")

    __table_args__ = (
        CheckConstraint("amount > 0", name="check_positive_budget_amount"),
        CheckConstraint("month >= 1 AND month <= 12", name="check_valid_budget_month"),
        CheckConstraint("year >= 2020 AND year <= 2100", name="check_valid_budget_year"),
        Index("ix_budgets_user_period", "user_id", "year", "month"),
        Index("ix_budgets_user_period_cat", "user_id", "year", "month", "category"),
    )

    def __repr__(self) -> str:
        cat_str = self.category or "Overall"
        return f"<Budget id={self.id} user={self.user_id} name='{self.name}' amount={self.amount} cat='{cat_str}' {self.year}-{self.month:02d}>"
