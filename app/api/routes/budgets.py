from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.budget import (
    BudgetCreateRequest,
    BudgetListResponse,
    BudgetProgressSummaryResponse,
    BudgetResponse,
    BudgetUpdateRequest,
)
from app.services.budget_service import BudgetService

router = APIRouter(prefix="/budgets", tags=["Budgets"])


@router.post(
    "",
    response_model=BudgetResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create Monthly or Category Budget",
    description="Creates a spending budget for the user. Set category to null for overall monthly budget."
)
def create_budget(
    budget_in: BudgetCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BudgetResponse:
    return BudgetService.create_budget(db=db, user_id=current_user.id, budget_in=budget_in)


@router.get(
    "",
    response_model=BudgetListResponse,
    summary="List Budgets with Progress & Alerts",
    description="Retrieves budgets for the specified month and year, enriched with real-time spent and alert status."
)
def list_budgets(
    month: Optional[int] = Query(None, ge=1, le=12, description="Target month (1-12)"),
    year: Optional[int] = Query(None, ge=2020, le=2100, description="Target year"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BudgetListResponse:
    return BudgetService.get_budgets(db=db, user_id=current_user.id, month=month, year=year)


@router.get(
    "/progress",
    response_model=BudgetProgressSummaryResponse,
    summary="Retrieve Budget Progress & Active Threshold Alerts",
    description="Returns high-level monthly budget progress, overall vs category breakdown, and 50%/80%/100% alerts."
)
def get_budget_progress(
    month: Optional[int] = Query(None, ge=1, le=12, description="Target month (1-12)"),
    year: Optional[int] = Query(None, ge=2020, le=2100, description="Target year"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BudgetProgressSummaryResponse:
    return BudgetService.get_progress_summary(db=db, user_id=current_user.id, month=month, year=year)


@router.get(
    "/{budget_id}",
    response_model=BudgetResponse,
    summary="Retrieve Single Budget",
    description="Returns single budget details with current progress calculations. Enforces user ownership."
)
def get_budget(
    budget_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BudgetResponse:
    return BudgetService.get_budget_by_id(db=db, budget_id=budget_id, user_id=current_user.id)


@router.patch(
    "/{budget_id}",
    response_model=BudgetResponse,
    summary="Update Budget",
    description="Updates name or ceiling amount of a budget. Enforces user ownership."
)
def update_budget(
    budget_id: int,
    update_in: BudgetUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BudgetResponse:
    return BudgetService.update_budget(
        db=db,
        budget_id=budget_id,
        user_id=current_user.id,
        update_in=update_in
    )


@router.delete(
    "/{budget_id}",
    status_code=status.HTTP_200_OK,
    summary="Delete Budget",
    description="Permanently deletes a budget. Enforces user ownership."
)
def delete_budget(
    budget_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> dict:
    BudgetService.delete_budget(db=db, budget_id=budget_id, user_id=current_user.id)
    return {"message": f"Budget {budget_id} deleted successfully."}
