import json
import logging
from typing import List, Optional
import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.schemas.analytics import (
    InsightSeverity,
    SpendingAnalyticsResponse,
    SpendingInsightItem,
    SpendingInsightsResponse,
)
from app.services.analytics_service import AnalyticsService

logger = logging.getLogger(__name__)


class InsightsService:
    """
    Generates evidence-based financial insights and observations.
    Uses deterministic factual rules by default, and can optionally augment
    with Google Gemini natural-language synthesis when configured.
    """

    @classmethod
    def generate_deterministic_insights(
        cls,
        analytics: SpendingAnalyticsResponse
    ) -> List[SpendingInsightItem]:
        insights: List[SpendingInsightItem] = []

        # Empty state handling
        if analytics.total_transactions == 0 or analytics.total_spent == 0:
            insights.append(SpendingInsightItem(
                type="empty_state",
                title="No Expense Records",
                message="No expenses recorded for this month yet. Add expenses or scan receipts to generate insights.",
                severity=InsightSeverity.INFO
            ))
            return insights

        # 1. Highest Spending Category
        if analytics.highest_spending_category:
            top = analytics.highest_spending_category
            insights.append(SpendingInsightItem(
                type="top_category",
                title="Top Spending Category",
                message=(
                    f"{top.category} is your highest expense category, "
                    f"totaling PKR {top.amount:,.2f} ({top.percentage:.1f}% of all expenses across {top.count} transactions)."
                ),
                severity=InsightSeverity.INFO,
                category=top.category
            ))

        # 2. Month-over-Month Comparison
        mom = analytics.month_comparison
        if mom.trend == "increased" and mom.previous_month_total > 0:
            insights.append(SpendingInsightItem(
                type="mom_comparison",
                title="Spending Increased",
                message=(
                    f"Your spending is {mom.percentage_change:.1f}% higher than last month "
                    f"(an increase of PKR {mom.difference:,.2f})."
                ),
                severity=InsightSeverity.WARNING
            ))
        elif mom.trend == "decreased" and mom.previous_month_total > 0:
            insights.append(SpendingInsightItem(
                type="mom_comparison",
                title="Spending Decreased",
                message=(
                    f"Good progress! Your spending is {abs(mom.percentage_change):.1f}% lower than last month "
                    f"(a reduction of PKR {abs(mom.difference):,.2f})."
                ),
                severity=InsightSeverity.SUCCESS
            ))
        elif mom.trend == "no_previous_data":
            insights.append(SpendingInsightItem(
                type="mom_comparison",
                title="First Month Baseline",
                message="This is your baseline month. Future months will compare against this spending pattern.",
                severity=InsightSeverity.INFO
            ))

        # 3. Average Daily Spending
        if analytics.average_daily_spending > 0:
            insights.append(SpendingInsightItem(
                type="daily_rate",
                title="Daily Spending Velocity",
                message=(
                    f"Your average spending velocity is PKR {analytics.average_daily_spending:,.2f} per day."
                ),
                severity=InsightSeverity.INFO
            ))

        # 4. Budget Status
        if analytics.budget_vs_actual:
            bva = analytics.budget_vs_actual
            if bva.percentage_used >= 100.0:
                insights.append(SpendingInsightItem(
                    type="budget_status",
                    title="Budget Exceeded",
                    message=(
                        f"You have exceeded your total monthly budget ceiling by "
                        f"PKR {abs(bva.remaining):,.2f} ({bva.percentage_used:.1f}% used)."
                    ),
                    severity=InsightSeverity.WARNING
                ))
            elif bva.percentage_used >= 80.0:
                insights.append(SpendingInsightItem(
                    type="budget_status",
                    title="Budget Warning (80% Reached)",
                    message=(
                        f"You have utilized {bva.percentage_used:.1f}% of your monthly budget. "
                        f"PKR {bva.remaining:,.2f} remaining."
                    ),
                    severity=InsightSeverity.WARNING
                ))
            else:
                insights.append(SpendingInsightItem(
                    type="budget_status",
                    title="Within Budget",
                    message=(
                        f"You are within budget limits with {bva.percentage_used:.1f}% used "
                        f"(PKR {bva.remaining:,.2f} remaining)."
                    ),
                    severity=InsightSeverity.SUCCESS
                ))

        return insights

    @classmethod
    async def get_insights(
        cls,
        db: Session,
        user_id: int,
        month: Optional[int] = None,
        year: Optional[int] = None
    ) -> SpendingInsightsResponse:
        analytics = AnalyticsService.get_spending_analytics(db, user_id, month=month, year=year)
        deterministic_items = cls.generate_deterministic_insights(analytics)

        # Generate headline
        if analytics.total_spent == 0:
            headline = "No expenses recorded for this month."
        elif analytics.highest_spending_category:
            headline = (
                f"Total recorded spending of PKR {analytics.total_spent:,.2f} led by "
                f"{analytics.highest_spending_category.category}."
            )
        else:
            headline = f"Total recorded spending of PKR {analytics.total_spent:,.2f} across {analytics.total_transactions} transactions."

        # If Gemini AI is configured and user has recorded expenses, optionally synthesize headline
        is_ai_gen = False
        provider_name = "deterministic_rules"

        if (
            settings.GEMINI_API_KEY
            and settings.GEMINI_API_KEY.strip()
            and analytics.total_transactions > 0
        ):
            try:
                ai_headline = await cls._synthesize_with_gemini(analytics)
                if ai_headline:
                    headline = ai_headline
                    is_ai_gen = True
                    provider_name = f"gemini ({settings.GEMINI_MODEL or 'gemini-1.5-flash'})"
            except Exception as e:
                logger.warning("Optional AI synthesis skipped, using deterministic headline: %s", e)

        return SpendingInsightsResponse(
            month=analytics.month,
            year=analytics.year,
            headline=headline,
            insights=deterministic_items,
            is_ai_generated=is_ai_gen,
            provider_used=provider_name
        )

    @classmethod
    async def _synthesize_with_gemini(cls, analytics: SpendingAnalyticsResponse) -> Optional[str]:
        """
        Sends ONLY aggregated financial figures to Gemini to compose a 1-sentence headline.
        Never transmits user IDs, names, or individual line-item secrets.
        """
        prompt = (
            f"You are a personal finance assistant. In one concise, professional sentence (under 25 words), "
            f"summarize this month's spending: Total spent is PKR {analytics.total_spent:,.2f} "
            f"across {analytics.total_transactions} transactions. "
            f"Top category: {analytics.highest_spending_category.category if analytics.highest_spending_category else 'None'}. "
            f"Month-over-month change: {analytics.month_comparison.percentage_change:.1f}% ({analytics.month_comparison.trend}). "
            f"Do not give investment advice. Return only the one sentence."
        )

        endpoint_url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{settings.GEMINI_MODEL or 'gemini-1.5-flash'}:generateContent?key={settings.GEMINI_API_KEY}"
        )

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.2, "maxOutputTokens": 60}
        }

        async with httpx.AsyncClient(timeout=6.0) as client:
            res = await client.post(endpoint_url, json=payload)
            if res.status_code == 200:
                data = res.json()
                text = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                clean_text = text.strip()
                if clean_text:
                    return clean_text
        return None
