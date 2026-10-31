from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.dashboard import DashboardFinancialSummaryResponse
from app.services.dashboard_service import DashboardService

router = APIRouter(prefix="/dashboard", tags=["Financial Dashboard"])


@router.get(
    "/financial-summary",
    response_model=DashboardFinancialSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Retrieve complete monthly financial dashboard summary"
)
def get_dashboard_financial_summary(
    month: Optional[int] = Query(None, ge=1, le=12, description="Target month (1-12)"),
    year: Optional[int] = Query(None, ge=2000, le=2100, description="Target year (e.g. 2026)"),
    currency: Optional[str] = Query(None, description="Optional override display currency (defaults to user preference)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> DashboardFinancialSummaryResponse:
    """
    Computes exact monthly financial metrics strictly for the requested month and year:
    - Monthly Income, Monthly Expenses, Net Cashflow, and Savings Rate.
    - Verified multi-currency conversions using Python Decimal precision.
    - Prominent deficit warning when expenses exceed income.
    - Month-specific Category Breakdown, Income vs Expense, Daily Trends, Recent Transactions, and Grounded Insights.
    """
    return DashboardService.get_financial_summary(
        db=db,
        user_id=current_user.id,
        month=month,
        year=year,
        override_currency=currency
    )


@router.get(
    "/overview",
    response_model=DashboardFinancialSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Alias for financial-summary"
)
def get_dashboard_overview(
    month: Optional[int] = Query(None, ge=1, le=12),
    year: Optional[int] = Query(None, ge=2000, le=2100),
    currency: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> DashboardFinancialSummaryResponse:
    return DashboardService.get_financial_summary(
        db=db,
        user_id=current_user.id,
        month=month,
        year=year,
        override_currency=currency
    )
