from decimal import Decimal
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, field_validator


class AdvisorOverviewResponse(BaseModel):
    total_income_this_month: Decimal = Field(..., description="Total income earned in current calendar month")
    total_expenses_this_month: Decimal = Field(..., description="Total operating expenses in current calendar month")
    net_cashflow: Decimal = Field(..., description="Total income minus operating expenses")
    savings_rate: float = Field(..., description="Percentage of income saved: (net cashflow / income) * 100")
    active_goals_count: int = Field(..., description="Count of goals in progress")
    total_savings_accumulated: Decimal = Field(..., description="Total capital saved across goals")
    pending_bills_count: int = Field(..., description="Unpaid upcoming bills count")
    pending_bills_total: Decimal = Field(..., description="Total upcoming bills obligation")
    overdue_bills_count: int = Field(..., description="Number of overdue bills")
    financial_health_score: int = Field(..., description="0-100 scoring calculated deterministically")
    financial_health_status: str = Field(..., description="Healthy | Moderate | Strained | Critical")


class AdvisorInsightItem(BaseModel):
    type: str = Field(..., description="strength | improvement | recommendation | alert")
    title: str
    description: str
    impact: str = Field("medium", description="high | medium | low")


class AdvisorInsightsResponse(BaseModel):
    summary_headline: str
    provider_used: str
    insights: List[AdvisorInsightItem]
    key_recommendation: str


class AdvisorChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=1000, description="User question or financial prompt")

    @field_validator("message")
    @classmethod
    def message_not_blank(cls, v: str) -> str:
        cleaned = v.strip()
        if not cleaned:
            raise ValueError("Message cannot be blank or whitespace-only.")
        return cleaned


class AdvisorChatResponse(BaseModel):
    reply: str
    provider_used: str
    grounded_metrics: Dict[str, Any]
    suggested_followups: List[str]
