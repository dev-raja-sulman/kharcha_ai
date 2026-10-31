from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String
from sqlalchemy.orm import relationship
from app.db.base import Base


class User(Base):
    """
    SQLAlchemy User model for KharchaAI authentication.
    Configured for local SQLite in Phase 1 and easily migratable to PostgreSQL in Phase 2.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    preferred_currency = Column(String(10), default="PKR", nullable=False)
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

    # Relationship to user's expenses (cascades on delete)
    expenses = relationship(
        "Expense",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    # Relationship to user's budgets (cascades on delete)
    budgets = relationship(
        "Budget",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    # Relationship to user's recurring expense rules (cascades on delete)
    recurring_expenses = relationship(
        "RecurringExpense",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    # Relationship to user's incomes (cascades on delete)
    incomes = relationship(
        "Income",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    # Relationship to user's income sources (cascades on delete)
    income_sources = relationship(
        "IncomeSource",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    # Relationship to user's saving goals (cascades on delete)
    saving_goals = relationship(
        "SavingGoal",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    # Relationship to user's saving contributions (cascades on delete)
    saving_contributions = relationship(
        "SavingContribution",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    # Relationship to user's tracked bills (cascades on delete)
    bills = relationship(
        "Bill",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} email='{self.email}' full_name='{self.full_name}'>"



