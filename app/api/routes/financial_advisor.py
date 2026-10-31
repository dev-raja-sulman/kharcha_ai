from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.financial_advisor import (
    AdvisorChatRequest,
    AdvisorChatResponse,
    AdvisorInsightsResponse,
    AdvisorOverviewResponse,
)
from app.services.financial_advisor_service import FinancialAdvisorService

router = APIRouter(prefix="/financial-advisor", tags=["AI Financial Advisor"])


@router.get(
    "/overview",
    response_model=AdvisorOverviewResponse,
    summary="Get aggregated financial metrics and health score"
)
def get_advisor_overview(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> AdvisorOverviewResponse:
    return FinancialAdvisorService.get_overview(
        db=db,
        user_id=current_user.id
    )


@router.get(
    "/insights",
    response_model=AdvisorInsightsResponse,
    summary="Get AI-synthesized financial insights, strengths, and recommendations"
)
async def get_advisor_insights(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> AdvisorInsightsResponse:
    return await FinancialAdvisorService.get_insights(
        db=db,
        user_id=current_user.id
    )


@router.post(
    "/chat",
    response_model=AdvisorChatResponse,
    summary="Ask AI Financial Advisor questions grounded in user metrics"
)
async def advisor_chat(
    req: AdvisorChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> AdvisorChatResponse:
    return await FinancialAdvisorService.chat(
        db=db,
        user_id=current_user.id,
        message=req.message
    )
