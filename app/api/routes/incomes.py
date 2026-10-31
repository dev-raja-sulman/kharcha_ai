from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.income import Income
from app.models.user import User
from app.schemas.income import (
    IncomeCreate,
    IncomeListResponse,
    IncomeResponse,
    IncomeSourceCreate,
    IncomeSourceResponse,
    IncomeSummaryResponse,
    IncomeUpdate,
)
from app.services.income_service import IncomeService

router = APIRouter(prefix="/incomes", tags=["Incomes"])
sources_router = APIRouter(prefix="/income-sources", tags=["Income Sources"])


def _to_income_response(inc: Income) -> IncomeResponse:
    return IncomeResponse(
        id=inc.id,
        user_id=inc.user_id,
        source_id=inc.source_id,
        source_name=inc.source.name if inc.source else None,
        title=inc.title,
        amount=inc.amount,
        currency=inc.currency,
        income_date=inc.income_date,
        payment_method=inc.payment_method,
        description=inc.description,
        created_at=inc.created_at,
        updated_at=inc.updated_at
    )


# ---------------------------------------------------------------------------
# Incomes CRUD Endpoints
# ---------------------------------------------------------------------------

@router.post(
    "",
    response_model=IncomeResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new income transaction"
)
def create_income(
    income_in: IncomeCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> IncomeResponse:
    """
    Log a new income entry strictly tied to the authenticated user.
    """
    income = IncomeService.create_income(
        db=db,
        user_id=current_user.id,
        income_in=income_in
    )
    return _to_income_response(income)


@router.get(
    "/summary",
    response_model=IncomeSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Get monthly or yearly income summaries"
)
def get_income_summary(
    month: Optional[int] = Query(None, ge=1, le=12, description="Month (1-12)"),
    year: Optional[int] = Query(None, ge=2000, le=2100, description="Year (e.g. 2026)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> IncomeSummaryResponse:
    """
    Compute total earned, source breakdown, and average per transaction for the user.
    """
    return IncomeService.get_income_summary(
        db=db,
        user_id=current_user.id,
        month=month,
        year=year
    )


@router.get(
    "",
    response_model=IncomeListResponse,
    status_code=status.HTTP_200_OK,
    summary="List and filter income transactions"
)
def list_incomes(
    start_date: Optional[date] = Query(None, description="Start date filter (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date filter (YYYY-MM-DD)"),
    source_id: Optional[int] = Query(None, description="Filter by income source ID"),
    search: Optional[str] = Query(None, description="Search keyword in title, description, or payment method"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> IncomeListResponse:
    """
    List income transactions with pagination and date/source filtering.
    """
    skip = (page - 1) * page_size
    items, total, total_amount = IncomeService.get_incomes(
        db=db,
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date,
        source_id=source_id,
        search=search,
        skip=skip,
        limit=page_size
    )
    return IncomeListResponse(
        total=total,
        page=page,
        page_size=page_size,
        total_amount=total_amount,
        items=[_to_income_response(item) for item in items]
    )


@router.get(
    "/{income_id}",
    response_model=IncomeResponse,
    status_code=status.HTTP_200_OK,
    summary="Get single income details"
)
def get_income(
    income_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> IncomeResponse:
    """
    Retrieve an income record by ID.
    """
    income = IncomeService.get_income_by_id(
        db=db,
        user_id=current_user.id,
        income_id=income_id
    )
    return _to_income_response(income)


@router.put(
    "/{income_id}",
    response_model=IncomeResponse,
    status_code=status.HTTP_200_OK,
    summary="Update an existing income transaction"
)
def update_income(
    income_id: int,
    income_in: IncomeUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> IncomeResponse:
    """
    Update an existing income transaction owned by the authenticated user.
    """
    updated = IncomeService.update_income(
        db=db,
        user_id=current_user.id,
        income_id=income_id,
        income_in=income_in
    )
    return _to_income_response(updated)


@router.delete(
    "/{income_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete an income transaction"
)
def delete_income(
    income_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> None:
    """
    Delete an income entry. Returns 204 on successful deletion.
    """
    IncomeService.delete_income(
        db=db,
        user_id=current_user.id,
        income_id=income_id
    )


# ---------------------------------------------------------------------------
# Income Sources Endpoints
# ---------------------------------------------------------------------------

@sources_router.get(
    "",
    response_model=List[IncomeSourceResponse],
    status_code=status.HTTP_200_OK,
    summary="List active income sources"
)
def list_income_sources(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[IncomeSourceResponse]:
    """
    Returns available income sources (e.g. Salary, Freelance, Business, etc.).
    Automatically seeds defaults for new users.
    """
    sources = IncomeService.get_sources(db=db, user_id=current_user.id)
    return [IncomeSourceResponse.model_validate(s) for s in sources]


@sources_router.post(
    "",
    response_model=IncomeSourceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a custom income source"
)
def create_income_source(
    source_in: IncomeSourceCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> IncomeSourceResponse:
    """
    Create a custom income source category for the user.
    """
    source = IncomeService.create_source(
        db=db,
        user_id=current_user.id,
        source_in=source_in
    )
    return IncomeSourceResponse.model_validate(source)
