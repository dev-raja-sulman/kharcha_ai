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


class IncomeSource(Base):
    """
    SQLAlchemy model for Income Sources (e.g. Salary, Freelance, Business, Investments, Rental Income, Other).
    Can be user-defined (user_id is set) or system defaults (user_id is None).
    """
    __tablename__ = "income_sources"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True
    )
    name = Column(String(100), nullable=False)
    description = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    # Relationships
    user = relationship("User", back_populates="income_sources")
    incomes = relationship(
        "Income",
        back_populates="source",
        cascade="all, delete-orphan",
        passive_deletes=True
    )

    __table_args__ = (
        Index("ix_income_sources_user_active", "user_id", "is_active"),
    )

    def __repr__(self) -> str:
        return f"<IncomeSource id={self.id} user_id={self.user_id} name='{self.name}'>"


class Income(Base):
    """
    SQLAlchemy model for Income Transactions in KharchaAI.
    Uses Numeric(12, 2) for exact currency amounts.
    Multi-tenant isolation enforced via user_id foreign key and composite indexes.
    """
    __tablename__ = "incomes"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    source_id = Column(
        Integer,
        ForeignKey("income_sources.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    title = Column(String(150), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    currency = Column(String(10), nullable=False, default="PKR")
    income_date = Column(Date, nullable=False, default=date.today, index=True)
    payment_method = Column(String(50), nullable=False, default="Bank Transfer")
    description = Column(String(500), nullable=True)
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
    user = relationship("User", back_populates="incomes")
    source = relationship("IncomeSource", back_populates="incomes")

    __table_args__ = (
        CheckConstraint("amount > 0", name="check_positive_income_amount"),
        Index("ix_incomes_user_date", "user_id", "income_date"),
        Index("ix_incomes_user_source", "user_id", "source_id"),
    )

    def __repr__(self) -> str:
        return f"<Income id={self.id} user_id={self.user_id} title='{self.title}' amount={self.amount} date={self.income_date}>"
