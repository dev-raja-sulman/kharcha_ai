from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.analytics import SpendingAnalyticsResponse, SpendingInsightsResponse
from app.services.analytics_service import AnalyticsService
from app.services.insights_service import InsightsService

router = APIRouter(prefix="/analytics", tags=["Analytics & Insights"])


@router.get(
    "/spending",
    response_model=SpendingAnalyticsResponse,
    summary="Retrieve Detailed Spending Analytics",
    description=(
        "Returns daily velocity, weekly blocks, category breakdowns, "
        "month-over-month comparisons, and budget vs actual analytics."
    )
)
def get_spending_analytics(
    month: Optional[int] = Query(None, ge=1, le=12, description="Target month (1-12)"),
    year: Optional[int] = Query(None, ge=2020, le=2100, description="Target year"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SpendingAnalyticsResponse:
    return AnalyticsService.get_spending_analytics(
        db=db,
        user_id=current_user.id,
        month=month,
        year=year
    )


@router.get(
    "/insights",
    response_model=SpendingInsightsResponse,
    summary="Retrieve AI Financial Spending Insights",
    description=(
        "Generates evidence-based observations from real user spending: "
        "MoM variance, category concentration, daily velocity, and budget limits."
    )
)
async def get_spending_insights(
    month: Optional[int] = Query(None, ge=1, le=12, description="Target month (1-12)"),
    year: Optional[int] = Query(None, ge=2020, le=2100, description="Target year"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SpendingInsightsResponse:
    return await InsightsService.get_insights(
        db=db,
        user_id=current_user.id,
        month=month,
        year=year
    )
