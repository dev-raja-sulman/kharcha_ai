from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.expense import (
    ExpenseCategory,
    ExpenseCreateRequest,
    ExpenseListResponse,
    ExpenseResponse,
    ExpenseSummaryResponse,
    ExpenseUpdateRequest,
)
from app.services.expense_service import ExpenseService

router = APIRouter(prefix="/expenses", tags=["Expenses"])


@router.post(
    "",
    response_model=ExpenseResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new expense"
)
def create_expense(
    req: ExpenseCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ExpenseResponse:
    """
    Create a new expense item strictly for the authenticated user.
    Client cannot specify or overwrite user_id.
    """
    expense = ExpenseService.create_expense(
        db=db,
        user_id=current_user.id,
        req=req
    )
    return ExpenseResponse.model_validate(expense)


@router.get(
    "/summary",
    response_model=ExpenseSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Get aggregated expense statistics and category summary"
)
def get_expense_summary(
    start_date: Optional[date] = Query(None, description="Start date filter (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date filter (YYYY-MM-DD)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ExpenseSummaryResponse:
    """
    Compute total spending, count, category distribution, and payment method stats.
    Strictly isolated to current user.
    """
    return ExpenseService.get_expense_summary(
        db=db,
        user_id=current_user.id,
        start_date=start_date,
        end_date=end_date
    )


@router.get(
    "/categories",
    response_model=list[str],
    status_code=status.HTTP_200_OK,
    summary="Get supported expense categories"
)
def get_categories(
    current_user: User = Depends(get_current_user)
) -> list[str]:
    """
    Retrieve list of canonical expense categories for UI dropdowns.
    """
    return ExpenseCategory.list_all()


@router.get(
    "",
    response_model=ExpenseListResponse,
    status_code=status.HTTP_200_OK,
    summary="List authenticated user's expenses with filtering and pagination"
)
def list_expenses(
    category: Optional[str] = Query(None, description="Filter by category (e.g. Food, Transport)"),
    start_date: Optional[date] = Query(None, description="Filter from date (inclusive)"),
    end_date: Optional[date] = Query(None, description="Filter to date (inclusive)"),
    search: Optional[str] = Query(None, description="Search term for title or notes"),
    skip: int = Query(0, ge=0, description="Offset for pagination"),
    limit: int = Query(50, ge=1, le=100, description="Page size limit"),
    sort_by: str = Query("date_desc", description="Sort order: date_desc, date_asc, amount_desc, amount_asc"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ExpenseListResponse:
    """
    Retrieve all expenses belonging to current user with optional filters.
    """
    items, total_count = ExpenseService.get_user_expenses(
        db=db,
        user_id=current_user.id,
        category=category,
        start_date=start_date,
        end_date=end_date,
        search=search,
        skip=skip,
        limit=limit,
        sort_by=sort_by
    )
    return ExpenseListResponse(
        items=[ExpenseResponse.model_validate(e) for e in items],
        total=total_count,
        skip=skip,
        limit=limit
    )


@router.get(
    "/{expense_id}",
    response_model=ExpenseResponse,
    status_code=status.HTTP_200_OK,
    summary="Retrieve a specific expense by ID"
)
def get_expense(
    expense_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ExpenseResponse:
    """
    Retrieve details of a single expense.
    Returns 404 if not found or if owned by another user.
    """
    expense = ExpenseService.get_expense_by_id(
        db=db,
        user_id=current_user.id,
        expense_id=expense_id
    )
    return ExpenseResponse.model_validate(expense)


@router.patch(
    "/{expense_id}",
    response_model=ExpenseResponse,
    status_code=status.HTTP_200_OK,
    summary="Update an existing expense"
)
def update_expense(
    expense_id: int,
    req: ExpenseUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ExpenseResponse:
    """
    Update fields of an existing expense owned by the current user.
    Returns 404 if not found or owned by another user.
    """
    expense = ExpenseService.update_expense(
        db=db,
        user_id=current_user.id,
        expense_id=expense_id,
        req=req
    )
    return ExpenseResponse.model_validate(expense)


@router.delete(
    "/{expense_id}",
    status_code=status.HTTP_200_OK,
    summary="Delete an expense"
)
def delete_expense(
    expense_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> dict:
    """
    Permanently delete an expense owned by the current user.
    Returns 404 if not found or owned by another user.
    """
    ExpenseService.delete_expense(
        db=db,
        user_id=current_user.id,
        expense_id=expense_id
    )
    return {"message": "Expense deleted successfully", "id": expense_id}
