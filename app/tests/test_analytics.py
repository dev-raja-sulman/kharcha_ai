from datetime import date
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "analytics_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Analytics Tester"
    })
    res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_unauthenticated_analytics_rejected(client: TestClient):
    """Unauthenticated requests to /api/v1/analytics/* must be rejected with 401."""
    res_s = client.get("/api/v1/analytics/spending")
    assert res_s.status_code == 401

    res_i = client.get("/api/v1/analytics/insights")
    assert res_i.status_code == 401


def test_empty_month_analytics(client: TestClient):
    """Months with zero transactions must return structured empty states without crashing."""
    headers = _get_auth_header(client, "empty_analytics@kharcha.ai")

    res = client.get("/api/v1/analytics/spending?month=10&year=2026", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["total_spent"] == "0.00"
    assert data["total_transactions"] == 0
    assert data["average_daily_spending"] == "0.00"
    assert data["highest_spending_category"] is None
    assert data["category_breakdown"] == []
    assert data["daily_spending"] == []
    assert data["month_comparison"]["trend"] == "no_previous_data"

    res_ins = client.get("/api/v1/analytics/insights?month=10&year=2026", headers=headers)
    assert res_ins.status_code == 200
    ins_data = res_ins.json()
    assert len(ins_data["insights"]) == 1
    assert ins_data["insights"][0]["type"] == "empty_state"


def test_spending_analytics_aggregations_and_comparison(client: TestClient):
    """Verify daily, weekly, category breakdowns, and month-over-month comparisons."""
    headers = _get_auth_header(client, "agg_analytics@kharcha.ai")

    # 1. Add Previous Month Expenses (September 2026: total 10,000)
    client.post("/api/v1/expenses", json={
        "title": "Sept Groceries",
        "amount": "10000.00",
        "category": "Food",
        "expense_date": "2026-09-15"
    }, headers=headers)

    # 2. Add Current Month Expenses (October 2026: Food 12,000 + Transport 6,000 = total 18,000)
    client.post("/api/v1/expenses", json={
        "title": "Supermarket",
        "amount": "8000.00",
        "category": "Food",
        "expense_date": "2026-10-04"
    }, headers=headers)
    client.post("/api/v1/expenses", json={
        "title": "Restaurant",
        "amount": "4000.00",
        "category": "Food",
        "expense_date": "2026-10-18"
    }, headers=headers)
    client.post("/api/v1/expenses", json={
        "title": "Fuel Shell",
        "amount": "6000.00",
        "category": "Transport",
        "expense_date": "2026-10-10"
    }, headers=headers)

    # 3. Create Budget for October (Overall 20,000)
    client.post("/api/v1/budgets", json={
        "name": "Oct Budget",
        "amount": "20000.00",
        "month": 10,
        "year": 2026
    }, headers=headers)

    # 4. Fetch Analytics
    res = client.get("/api/v1/analytics/spending?month=10&year=2026", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert data["total_spent"] == "18000.00"
    assert data["total_transactions"] == 3

    # Category breakdown: Food (12,000 - 66.67%), Transport (6,000 - 33.33%)
    assert len(data["category_breakdown"]) == 2
    assert data["highest_spending_category"]["category"] == "Food"
    assert data["highest_spending_category"]["amount"] == "12000.00"
    assert data["category_breakdown"][0]["category"] == "Food"
    assert data["category_breakdown"][1]["category"] == "Transport"

    # MoM Comparison: 18,000 vs 10,000 (+8,000 or +80.0%)
    mom = data["month_comparison"]
    assert mom["current_month_total"] == "18000.00"
    assert mom["previous_month_total"] == "10000.00"
    assert mom["difference"] == "8000.00"
    assert mom["percentage_change"] == 80.0
    assert mom["trend"] == "increased"

    # Budget vs Actual: Budget 20,000, Spent 18,000, Remaining 2,000 (90%)
    bva = data["budget_vs_actual"]
    assert bva is not None
    assert bva["total_budgeted"] == "20000.00"
    assert bva["total_spent"] == "18000.00"
    assert bva["remaining"] == "2000.00"
    assert bva["percentage_used"] == 90.0

    # 5. Fetch Insights
    res_ins = client.get("/api/v1/analytics/insights?month=10&year=2026", headers=headers)
    assert res_ins.status_code == 200
    ins = res_ins.json()
    assert len(ins["insights"]) >= 3
    # Look for top_category, mom_comparison, and budget_status
    types = [i["type"] for i in ins["insights"]]
    assert "top_category" in types
    assert "mom_comparison" in types
    assert "budget_status" in types


def test_analytics_multi_user_isolation(client: TestClient):
    """User 2 must not see User 1's expenses in their analytics calculations."""
    headers1 = _get_auth_header(client, "user1_analytics@kharcha.ai")
    headers2 = _get_auth_header(client, "user2_analytics@kharcha.ai")

    # User 1 adds expenses
    client.post("/api/v1/expenses", json={
        "title": "User 1 Heavy Spending",
        "amount": "75000.00",
        "category": "Shopping",
        "expense_date": "2026-10-15"
    }, headers=headers1)

    # User 2 analytics must remain completely 0.00
    res2 = client.get("/api/v1/analytics/spending?month=10&year=2026", headers=headers2)
    assert res2.status_code == 200
    assert res2.json()["total_spent"] == "0.00"
    assert res2.json()["total_transactions"] == 0
    assert res2.json()["highest_spending_category"] is None
