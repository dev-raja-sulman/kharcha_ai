from calendar import monthrange
from datetime import date
from decimal import Decimal
import logging
import re
from typing import Any, Dict, List, Optional, Tuple
import httpx
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.bill import Bill
from app.models.expense import Expense
from app.models.income import Income
from app.models.saving_goal import SavingGoal
from app.schemas.financial_advisor import (
    AdvisorChatResponse,
    AdvisorInsightItem,
    AdvisorInsightsResponse,
    AdvisorOverviewResponse,
)

logger = logging.getLogger(__name__)


class FinancialAdvisorService:
    """
    AI Financial Advisor service providing zero-PII grounded financial intelligence.
    Combines deterministic financial calculus with Google Gemini AI synthesis and
    robust fallback mechanisms.
    """

    @classmethod
    def _get_monthly_bounds(cls, target_date: Optional[date] = None) -> Tuple[date, date]:
        ref_date = target_date or date.today()
        _, last_day = monthrange(ref_date.year, ref_date.month)
        return date(ref_date.year, ref_date.month, 1), date(ref_date.year, ref_date.month, last_day)

    @classmethod
    def get_overview(cls, db: Session, user_id: int) -> AdvisorOverviewResponse:
        """
        Calculates personal finance aggregates across Income, Expense, Bills, and Savings Goals ledgers.
        """
        month_start, month_end = cls._get_monthly_bounds()

        # 1. Monthly Income
        income_query = db.query(func.coalesce(func.sum(Income.amount), 0)).filter(
            Income.user_id == user_id,
            Income.income_date >= month_start,
            Income.income_date <= month_end
        ).scalar()
        total_income = Decimal(str(income_query))

        # 2. Monthly Expenses
        expense_query = db.query(func.coalesce(func.sum(Expense.amount), 0)).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= month_start,
            Expense.expense_date <= month_end
        ).scalar()
        total_expenses = Decimal(str(expense_query))

        # 3. Net Cashflow & Savings Rate
        net_cashflow = total_income - total_expenses
        if total_income > Decimal("0.00"):
            savings_rate = float(round((net_cashflow / total_income) * Decimal("100.0"), 1))
        else:
            savings_rate = 0.0

        # 4. Savings Goals
        active_goals = db.query(SavingGoal).filter(
            SavingGoal.user_id == user_id,
            SavingGoal.status == "in_progress"
        ).all()
        active_goals_count = len(active_goals)
        total_savings_accumulated = sum(
            (Decimal(str(g.current_amount)) for g in active_goals),
            Decimal("0.00")
        )

        # 5. Bills & Obligations
        today = date.today()
        # Mark overdue bills
        overdue_bills = db.query(Bill).filter(
            Bill.user_id == user_id,
            Bill.status.in_(["unpaid", "overdue"]),
            Bill.due_date < today
        ).all()
        for b in overdue_bills:
            b.status = "overdue"
        if overdue_bills:
            db.commit()

        pending_bills = db.query(Bill).filter(
            Bill.user_id == user_id,
            Bill.status == "unpaid"
        ).all()
        pending_bills_count = len(pending_bills)
        pending_bills_total = sum(
            (Decimal(str(b.amount)) for b in pending_bills),
            Decimal("0.00")
        )

        overdue_count = len(overdue_bills)

        # 6. Deterministic Financial Health Score (0 - 100)
        score = 0
        # Savings Rate Component (max 40 pts)
        if savings_rate >= 30.0:
            score += 40
        elif savings_rate >= 15.0:
            score += 30
        elif savings_rate > 0.0:
            score += 15
        elif savings_rate == 0.0 and total_income > 0:
            score += 5

        # Overdue Bills Component (max 30 pts)
        if overdue_count == 0:
            score += 30
        elif overdue_count == 1:
            score += 10
        else:
            score += 0

        # Positive Cashflow Component (max 20 pts)
        if net_cashflow > Decimal("0.00"):
            score += 20
        elif net_cashflow == Decimal("0.00"):
            score += 10

        # Savings Goals Active Component (max 10 pts)
        if active_goals_count > 0:
            score += 10

        if score >= 80:
            health_status = "Healthy"
        elif score >= 60:
            health_status = "Moderate"
        elif score >= 40:
            health_status = "Strained"
        else:
            health_status = "Critical"

        return AdvisorOverviewResponse(
            total_income_this_month=total_income,
            total_expenses_this_month=total_expenses,
            net_cashflow=net_cashflow,
            savings_rate=savings_rate,
            active_goals_count=active_goals_count,
            total_savings_accumulated=total_savings_accumulated,
            pending_bills_count=pending_bills_count,
            pending_bills_total=pending_bills_total,
            overdue_bills_count=overdue_count,
            financial_health_score=score,
            financial_health_status=health_status
        )

    @classmethod
    async def _call_gemini(cls, prompt: str) -> Optional[str]:
        """
        Transmits zero-PII prompt to Gemini API with strict timeout handling.
        """
        api_key = (settings.GEMINI_API_KEY or "").strip()
        if not api_key:
            return None

        endpoint_url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{settings.GEMINI_MODEL or 'gemini-1.5-flash'}:generateContent?key={api_key}"
        )

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.25, "maxOutputTokens": 350}
        }

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.post(endpoint_url, json=payload)
                if res.status_code == 200:
                    data = res.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                        return text.strip() if text else None
        except Exception as e:
            logger.warning(f"Gemini API request failed: {e}")
            return None

        return None

    @classmethod
    async def get_insights(cls, db: Session, user_id: int) -> AdvisorInsightsResponse:
        """
        Generates structured financial insights and actionable recommendations.
        Uses Gemini when available, with guaranteed deterministic rules fallback.
        """
        overview = cls.get_overview(db, user_id)
        month_start, month_end = cls._get_monthly_bounds()

        # Top expense categories this month
        top_cats = db.query(
            Expense.category,
            func.sum(Expense.amount).label("cat_total")
        ).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= month_start,
            Expense.expense_date <= month_end
        ).group_by(Expense.category).order_by(func.sum(Expense.amount).desc()).limit(3).all()

        insights: List[AdvisorInsightItem] = []

        # 1. Strengths
        if overview.net_cashflow > Decimal("0.00"):
            insights.append(AdvisorInsightItem(
                type="strength",
                title="Positive Monthly Cashflow",
                description=f"You retained a surplus of PKR {overview.net_cashflow:,.2f} this month with a savings rate of {overview.savings_rate}%.",
                impact="high"
            ))
        if overview.overdue_bills_count == 0:
            insights.append(AdvisorInsightItem(
                type="strength",
                title="Bills Under Control",
                description="Zero overdue bills detected. All scheduled obligations are in good standing.",
                impact="medium"
            ))
        if overview.active_goals_count > 0:
            insights.append(AdvisorInsightItem(
                type="strength",
                title="Active Savings Discipline",
                description=f"You have {overview.active_goals_count} savings goal(s) with PKR {overview.total_savings_accumulated:,.2f} saved.",
                impact="medium"
            ))

        # 2. Improvements / Alerts
        if overview.overdue_bills_count > 0:
            insights.append(AdvisorInsightItem(
                type="alert",
                title="Overdue Bills Requiring Settlement",
                description=f"You have {overview.overdue_bills_count} overdue bill(s). Settle these promptly to avoid late penalties or utility disconnects.",
                impact="high"
            ))
        if overview.net_cashflow < Decimal("0.00"):
            insights.append(AdvisorInsightItem(
                type="improvement",
                title="Negative Cashflow Deficit",
                description=f"Your expenses exceed your recorded income by PKR {abs(overview.net_cashflow):,.2f}. Review high-discretionary spending categories.",
                impact="high"
            ))
        elif overview.total_income_this_month == Decimal("0.00") and overview.total_expenses_this_month > Decimal("0.00"):
            insights.append(AdvisorInsightItem(
                type="improvement",
                title="No Income Recorded This Month",
                description="You have logged expenses without recording any income streams. Log your income to enable accurate savings analysis.",
                impact="high"
            ))

        if top_cats and overview.total_expenses_this_month > Decimal("0.00"):
            top_cat_name, top_cat_amt = top_cats[0][0], Decimal(str(top_cats[0][1]))
            ratio = (top_cat_amt / overview.total_expenses_this_month) * Decimal("100.0")
            if ratio > Decimal("35.0"):
                insights.append(AdvisorInsightItem(
                    type="improvement",
                    title=f"High Spending Concentration in {top_cat_name}",
                    description=f"{top_cat_name} accounts for {float(ratio):.1f}% (PKR {top_cat_amt:,.2f}) of your total monthly expenditure.",
                    impact="medium"
                ))

        # Default fallback headline and recommendation
        if overview.net_cashflow > Decimal("0.00"):
            default_headline = f"Strong financial position with PKR {overview.net_cashflow:,.2f} retained surplus and {overview.financial_health_status} health."
            default_rec = f"Consider directing 40% of your PKR {overview.net_cashflow:,.2f} surplus toward your active savings goals."
        elif overview.overdue_bills_count > 0:
            default_headline = f"Urgent attention needed: {overview.overdue_bills_count} overdue bill(s) impacting your financial health score."
            default_rec = "Prioritize paying overdue bills immediately to protect your credit and utility continuity."
        else:
            default_headline = f"Your current financial standing is {overview.financial_health_status} with PKR {overview.total_expenses_this_month:,.2f} in operating expenses."
            default_rec = "Record all regular income streams and cap top discretionary expenses to maintain a healthy cash reserve."

        # If Gemini is configured, synthesize dynamic overview
        summary_headline = default_headline
        key_rec = default_rec
        provider_name = "deterministic_rule_engine"

        gemini_prompt = (
            f"You are KharchaAI's expert financial planner. Based on these ANONYMOUS, ZERO-PII monthly metrics: "
            f"Monthly Income: PKR {overview.total_income_this_month:,.2f}; "
            f"Monthly Expenses: PKR {overview.total_expenses_this_month:,.2f}; "
            f"Net Cashflow: PKR {overview.net_cashflow:,.2f}; "
            f"Savings Rate: {overview.savings_rate}%; "
            f"Financial Health Score: {overview.financial_health_score}/100 ({overview.financial_health_status}); "
            f"Overdue Bills: {overview.overdue_bills_count}; "
            f"Pending Bills: PKR {overview.pending_bills_total:,.2f}; "
            f"Active Goals: {overview.active_goals_count}. "
            f"Provide exactly TWO lines: "
            f"Line 1 (HEADLINE): A punchy 1-sentence assessment (max 20 words). "
            f"Line 2 (RECOMMENDATION): A high-impact 1-sentence action step (max 25 words). "
            f"Do not include names or currency other than PKR. Strictly 2 lines without markdown labels."
        )

        ai_response = await cls._call_gemini(gemini_prompt)
        if ai_response:
            lines = [l.strip() for l in ai_response.split("\n") if l.strip()]
            if len(lines) >= 2:
                summary_headline = lines[0].replace("HEADLINE:", "").strip()
                key_rec = lines[1].replace("RECOMMENDATION:", "").strip()
                provider_name = f"gemini ({settings.GEMINI_MODEL or 'gemini-1.5-flash'})"

        return AdvisorInsightsResponse(
            summary_headline=summary_headline,
            provider_used=provider_name,
            insights=insights,
            key_recommendation=key_rec
        )

    @classmethod
    async def chat(
        cls,
        db: Session,
        user_id: int,
        message: str
    ) -> AdvisorChatResponse:
        """
        Answers user financial inquiries grounded in their real ledger metrics.
        """
        overview = cls.get_overview(db, user_id)
        month_start, month_end = cls._get_monthly_bounds()

        # Category breakdown for context
        top_cats = db.query(
            Expense.category,
            func.sum(Expense.amount).label("cat_total")
        ).filter(
            Expense.user_id == user_id,
            Expense.expense_date >= month_start,
            Expense.expense_date <= month_end
        ).group_by(Expense.category).order_by(func.sum(Expense.amount).desc()).limit(4).all()

        cat_summary = ", ".join([f"{c[0]}: PKR {Decimal(str(c[1])):,.2f}" for c in top_cats]) or "None"

        grounded_data: Dict[str, Any] = {
            "total_income": float(overview.total_income_this_month),
            "total_expenses": float(overview.total_expenses_this_month),
            "net_cashflow": float(overview.net_cashflow),
            "savings_rate_pct": overview.savings_rate,
            "health_score": overview.financial_health_score,
            "health_status": overview.financial_health_status,
            "overdue_bills_count": overview.overdue_bills_count,
            "pending_bills_total": float(overview.pending_bills_total),
            "active_goals_count": overview.active_goals_count,
            "total_savings": float(overview.total_savings_accumulated),
        }

        suggested_followups = [
            "Can I afford a PKR 50,000 purchase?",
            "How can I improve my savings rate?",
            "What are my highest expense categories this month?",
            "Am I on track for my savings goals?"
        ]

        # 1. Try Gemini first
        gemini_prompt = (
            f"You are KharchaAI's Certified Financial Advisor. "
            f"Answer the user's inquiry strictly grounded in their real financial metrics: "
            f"- Monthly Income: PKR {overview.total_income_this_month:,.2f}\n"
            f"- Monthly Expenses: PKR {overview.total_expenses_this_month:,.2f}\n"
            f"- Net Cashflow: PKR {overview.net_cashflow:,.2f}\n"
            f"- Savings Rate: {overview.savings_rate}%\n"
            f"- Financial Health: {overview.financial_health_score}/100 ({overview.financial_health_status})\n"
            f"- Overdue Bills: {overview.overdue_bills_count}\n"
            f"- Upcoming Bills: PKR {overview.pending_bills_total:,.2f}\n"
            f"- Active Goals: {overview.active_goals_count} (PKR {overview.total_savings_accumulated:,.2f} accumulated)\n"
            f"- Top Spending Categories: {cat_summary}\n\n"
            f"User Question: \"{message}\"\n\n"
            f"Guidelines:\n"
            f"1. Be concise, direct, helpful, and polite (2 to 4 paragraphs max).\n"
            f"2. Use their exact numbers (PKR) without hallucinating fictional transactions.\n"
            f"3. Never give speculative stock or crypto trading recommendations.\n"
            f"4. Give concrete, realistic budgeting and cash management steps."
        )

        ai_reply = await cls._call_gemini(gemini_prompt)
        if ai_reply:
            return AdvisorChatResponse(
                reply=ai_reply,
                provider_used=f"gemini ({settings.GEMINI_MODEL or 'gemini-1.5-flash'})",
                grounded_metrics=grounded_data,
                suggested_followups=suggested_followups
            )

        # 2. Deterministic Rule-Based Fallback
        lower_msg = message.lower()

        # Check for affordability query (e.g. "afford 50000", "buy laptop 150000")
        numbers_found = re.findall(r"\b\d+(?:,\d+)*(?:\.\d+)?\b", lower_msg.replace("pkr", "").replace("rs", ""))
        target_cost = None
        if numbers_found:
            try:
                target_cost = Decimal(numbers_found[0].replace(",", ""))
            except Exception:
                pass

        if any(w in lower_msg for w in ["afford", "buy", "purchase", "cost"]) and target_cost is not None and target_cost > 0:
            if overview.net_cashflow >= target_cost:
                reply = (
                    f"Yes, based on your current cashflow you can afford a PKR {target_cost:,.2f} expense. "
                    f"Your monthly surplus is currently PKR {overview.net_cashflow:,.2f}. "
                    f"After this purchase, your remaining monthly cashflow would be PKR {(overview.net_cashflow - target_cost):,.2f}. "
                    f"However, please ensure you account for your PKR {overview.pending_bills_total:,.2f} in upcoming bills."
                )
            elif overview.total_savings_accumulated >= target_cost:
                reply = (
                    f"While your monthly cash surplus is PKR {overview.net_cashflow:,.2f} (which is less than PKR {target_cost:,.2f}), "
                    f"you have accumulated PKR {overview.total_savings_accumulated:,.2f} across your savings goals. "
                    f"Using your savings goal capital would allow this purchase, but might delay your target goals."
                )
            else:
                shortfall = target_cost - max(Decimal("0.00"), overview.net_cashflow)
                reply = (
                    f"Currently, this purchase of PKR {target_cost:,.2f} would strain your finances by approximately PKR {shortfall:,.2f}. "
                    f"Your current monthly surplus is PKR {overview.net_cashflow:,.2f}. "
                    f"We recommend creating a targeted Savings Goal in KharchaAI and contributing PKR {(target_cost / Decimal('3.0')):,.2f} over 3 months."
                )

        elif any(w in lower_msg for w in ["saving", "save", "boost", "rate"]):
            reply = (
                f"Your current savings rate is {overview.savings_rate}% (Net Surplus: PKR {overview.net_cashflow:,.2f}). "
                f"To boost your savings rate toward the recommended 20% benchmark: "
                f"1. Review your top spending: {cat_summary}. "
                f"2. Ensure upcoming bills (PKR {overview.pending_bills_total:,.2f}) are paid on time to avoid penalties. "
                f"3. Set up automated transfers to your {overview.active_goals_count} active savings goal(s)."
            )

        elif any(w in lower_msg for w in ["bill", "overdue", "due", "obligation"]):
            if overview.overdue_bills_count > 0:
                reply = (
                    f"You have {overview.overdue_bills_count} overdue bill(s) that require immediate settlement! "
                    f"Additionally, you have {overview.pending_bills_count} upcoming bills totaling PKR {overview.pending_bills_total:,.2f}. "
                    f"Check the Bills screen in KharchaAI to mark them paid and synchronize them with your expenses."
                )
            else:
                reply = (
                    f"All your bills are currently in good standing! You have {overview.pending_bills_count} upcoming bills "
                    f"totaling PKR {overview.pending_bills_total:,.2f} due soon."
                )

        else:
            # General status summary
            reply = (
                f"Here is your financial status overview: "
                f"Your Financial Health Score is {overview.financial_health_score}/100 ({overview.financial_health_status}). "
                f"Total Income: PKR {overview.total_income_this_month:,.2f} | Operating Expenses: PKR {overview.total_expenses_this_month:,.2f}. "
                f"Net Cashflow: PKR {overview.net_cashflow:,.2f} with a {overview.savings_rate}% savings rate. "
                f"You have {overview.active_goals_count} active savings goal(s) and {overview.pending_bills_count} upcoming bill(s)."
            )

        return AdvisorChatResponse(
            reply=reply,
            provider_used="deterministic_rule_engine",
            grounded_metrics=grounded_data,
            suggested_followups=suggested_followups
        )
