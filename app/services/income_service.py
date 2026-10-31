from calendar import monthrange
from datetime import date
from decimal import Decimal
import logging
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session, joinedload

from app.models.income import Income, IncomeSource
from app.schemas.income import (
    IncomeCreate,
    IncomeResponse,
    IncomeSourceCreate,
    IncomeSummaryResponse,
    IncomeUpdate,
    SourceBreakdownItem,
)

logger = logging.getLogger(__name__)

DEFAULT_INCOME_SOURCES = [
    {"name": "Salary", "description": "Primary employment salary or wages"},
    {"name": "Freelance", "description": "Client projects, consulting, and contract work"},
    {"name": "Business", "description": "Business revenue and profits"},
    {"name": "Investments", "description": "Dividends, capital gains, and interest"},
    {"name": "Rental Income", "description": "Property rental and lease payments"},
    {"name": "Other Income", "description": "Gifts, rewards, refunds, and miscellaneous"},
]


class IncomeService:
    """
    Business logic for Income Management and Income Sources in KharchaAI.
    Enforces strict multi-tenant isolation, Decimal financial accuracy, and data consistency.
    """

    @classmethod
    def ensure_default_sources(cls, db: Session, user_id: int) -> List[IncomeSource]:
        """
        Seeds standard default income sources for the user if they have none.
        """
        existing = db.query(IncomeSource).filter(
            or_(IncomeSource.user_id == user_id, IncomeSource.user_id.is_(None))
        ).first()

        if not existing:
            for item in DEFAULT_INCOME_SOURCES:
                source = IncomeSource(
                    user_id=user_id,
                    name=item["name"],
                    description=item["description"],
                    is_active=True
                )
                db.add(source)
            db.commit()

        return db.query(IncomeSource).filter(
            or_(IncomeSource.user_id == user_id, IncomeSource.user_id.is_(None)),
            IncomeSource.is_active == True  # noqa: E712
        ).order_by(IncomeSource.id).all()

    @classmethod
    def get_sources(cls, db: Session, user_id: int) -> List[IncomeSource]:
        """
        Retrieves all active income sources accessible to the user (user-created or defaults).
        """
        sources = db.query(IncomeSource).filter(
            or_(IncomeSource.user_id == user_id, IncomeSource.user_id.is_(None)),
            IncomeSource.is_active == True  # noqa: E712
        ).order_by(IncomeSource.name).all()

        if not sources:
            sources = cls.ensure_default_sources(db, user_id)
        return sources

    @classmethod
    def create_source(cls, db: Session, user_id: int, source_in: IncomeSourceCreate) -> IncomeSource:
        """
        Creates a custom income source for the authenticated user.
        """
        existing = db.query(IncomeSource).filter(
            IncomeSource.user_id == user_id,
            func.lower(IncomeSource.name) == source_in.name.strip().lower()
        ).first()

        if existing:
            if not existing.is_active:
                existing.is_active = True
                existing.description = source_in.description
                db.commit()
                db.refresh(existing)
                return existing
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"An income source named '{source_in.name}' already exists."
            )

        new_source = IncomeSource(
            user_id=user_id,
            name=source_in.name.strip(),
            description=source_in.description,
            is_active=source_in.is_active
        )
        db.add(new_source)
        db.commit()
        db.refresh(new_source)
        return new_source

    @classmethod
    def create_income(cls, db: Session, user_id: int, income_in: IncomeCreate) -> Income:
        """
        Creates a new income record for the user.
        """
        # Validate source_id belongs to user or is global
        if income_in.source_id is not None:
            source = db.query(IncomeSource).filter(
                IncomeSource.id == income_in.source_id,
                or_(IncomeSource.user_id == user_id, IncomeSource.user_id.is_(None)),
                IncomeSource.is_active == True  # noqa: E712
            ).first()
            if not source:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Income source with id {income_in.source_id} not found or inactive."
                )

        new_income = Income(
            user_id=user_id,
            source_id=income_in.source_id,
            title=income_in.title.strip(),
            amount=income_in.amount,
            currency=income_in.currency.upper(),
            income_date=income_in.income_date,
            payment_method=income_in.payment_method,
            description=income_in.description
        )
        db.add(new_income)
        db.commit()
        db.refresh(new_income)
        return new_income

    @classmethod
    def get_incomes(
        cls,
        db: Session,
        user_id: int,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        source_id: Optional[int] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 50
    ) -> Tuple[List[Income], int, Decimal]:
        """
        Retrieves paginated income records for the authenticated user with filters.
        Returns: (items, total_count, total_filtered_amount)
        """
        query = db.query(Income).options(joinedload(Income.source)).filter(Income.user_id == user_id)

        if start_date:
            query = query.filter(Income.income_date >= start_date)
        if end_date:
            query = query.filter(Income.income_date <= end_date)
        if source_id:
            query = query.filter(Income.source_id == source_id)
        if search and search.strip():
            term = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    Income.title.ilike(term),
                    Income.description.ilike(term),
                    Income.payment_method.ilike(term)
                )
            )

        total_count = query.count()

        # Calculate sum for filtered records
        sum_val = query.with_entities(func.coalesce(func.sum(Income.amount), Decimal("0.00"))).scalar()
        total_amount = Decimal(str(sum_val or 0))

        items = query.order_by(Income.income_date.desc(), Income.id.desc()).offset(skip).limit(limit).all()
        return items, total_count, total_amount

    @classmethod
    def get_income_by_id(cls, db: Session, user_id: int, income_id: int) -> Income:
        """
        Fetches an individual income by ID ensuring multi-user tenant ownership.
        """
        income = db.query(Income).options(joinedload(Income.source)).filter(
            Income.id == income_id,
            Income.user_id == user_id
        ).first()

        if not income:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Income transaction with id {income_id} not found."
            )
        return income

    @classmethod
    def update_income(cls, db: Session, user_id: int, income_id: int, income_in: IncomeUpdate) -> Income:
        """
        Updates an existing income entry.
        """
        income = cls.get_income_by_id(db, user_id, income_id)

        update_data = income_in.model_dump(exclude_unset=True)

        if "source_id" in update_data and update_data["source_id"] is not None:
            source = db.query(IncomeSource).filter(
                IncomeSource.id == update_data["source_id"],
                or_(IncomeSource.user_id == user_id, IncomeSource.user_id.is_(None)),
                IncomeSource.is_active == True  # noqa: E712
            ).first()
            if not source:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Income source with id {update_data['source_id']} not found."
                )

        for key, value in update_data.items():
            setattr(income, key, value)

        db.commit()
        db.refresh(income)
        return income

    @classmethod
    def delete_income(cls, db: Session, user_id: int, income_id: int) -> None:
        """
        Permanently deletes an income entry owned by the user.
        """
        income = cls.get_income_by_id(db, user_id, income_id)
        db.delete(income)
        db.commit()

    @classmethod
    def get_income_summary(
        cls,
        db: Session,
        user_id: int,
        month: Optional[int] = None,
        year: Optional[int] = None
    ) -> IncomeSummaryResponse:
        """
        Computes summary metrics, monthly/yearly totals, and source breakdown.
        """
        query = db.query(Income).filter(Income.user_id == user_id)

        if year:
            if month:
                _, last_day = monthrange(year, month)
                start_d = date(year, month, 1)
                end_d = date(year, month, last_day)
                query = query.filter(Income.income_date >= start_d, Income.income_date <= end_d)
            else:
                start_d = date(year, 1, 1)
                end_d = date(year, 12, 31)
                query = query.filter(Income.income_date >= start_d, Income.income_date <= end_d)

        incomes = query.options(joinedload(Income.source)).all()

        total_transactions = len(incomes)
        total_income = sum((Decimal(str(inc.amount)) for inc in incomes), Decimal("0.00"))

        # Group by source
        source_map = {}
        for inc in incomes:
            s_name = inc.source.name if inc.source else "Other Income"
            s_id = inc.source_id
            if s_name not in source_map:
                source_map[s_name] = {
                    "source_id": s_id,
                    "source_name": s_name,
                    "total_amount": Decimal("0.00"),
                    "count": 0
                }
            source_map[s_name]["total_amount"] += Decimal(str(inc.amount))
            source_map[s_name]["count"] += 1

        breakdown: List[SourceBreakdownItem] = []
        for s_name, data in sorted(source_map.items(), key=lambda x: x[1]["total_amount"], reverse=True):
            pct = (float(data["total_amount"]) / float(total_income) * 100.0) if total_income > 0 else 0.0
            breakdown.append(SourceBreakdownItem(
                source_id=data["source_id"],
                source_name=s_name,
                total_amount=data["total_amount"],
                percentage=round(pct, 2),
                transaction_count=data["count"]
            ))

        avg = (total_income / total_transactions) if total_transactions > 0 else Decimal("0.00")

        return IncomeSummaryResponse(
            total_income=total_income,
            total_transactions=total_transactions,
            currency="PKR",
            month=month,
            year=year,
            source_breakdown=breakdown,
            average_income_per_entry=round(avg, 2)
        )
