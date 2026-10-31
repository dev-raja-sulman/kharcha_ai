from datetime import date, timedelta
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "advisor_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Advisor Tester"
    })
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_unauthenticated_advisor_access(client: TestClient):
    assert client.get("/api/v1/financial-advisor/overview").status_code == 401
    assert client.get("/api/v1/financial-advisor/insights").status_code == 401
    assert client.post("/api/v1/financial-advisor/chat", json={"message": "Can I buy a phone?"}).status_code == 401


def test_advisor_overview_calculation(client: TestClient):
    headers = _get_auth_header(client, "overview_advisor@kharcha.ai")
    today = date.today()

    # 1. Log Income (PKR 100,000)
    client.post("/api/v1/incomes", json={
        "title": "Monthly Salary",
        "amount": "100000.00",
        "income_date": str(today),
        "description": "Monthly software salary"
    }, headers=headers)

    # 2. Log Expense (PKR 40,000)
    client.post("/api/v1/expenses", json={
        "title": "Apartment Rent",
        "category": "Rent",
        "amount": "40000.00",
        "expense_date": str(today),
        "payment_method": "Bank Transfer"
    }, headers=headers)

    # 3. Create Goal
    client.post("/api/v1/saving-goals", json={
        "title": "Emergency Fund",
        "target_amount": "200000.00",
        "start_date": str(today),
        "target_date": str(today + timedelta(days=180))
    }, headers=headers)

    # 4. Create Bill
    client.post("/api/v1/bills", json={
        "title": "Internet",
        "category": "Internet",
        "amount": "4500.00",
        "due_date": str(today + timedelta(days=5))
    }, headers=headers)

    res = client.get("/api/v1/financial-advisor/overview", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert Decimal(data["total_income_this_month"]) == Decimal("100000.00")
    assert Decimal(data["total_expenses_this_month"]) == Decimal("40000.00")
    assert Decimal(data["net_cashflow"]) == Decimal("60000.00")
    assert data["savings_rate"] == 60.0
    assert data["active_goals_count"] == 1
    assert data["pending_bills_count"] == 1
    assert Decimal(data["pending_bills_total"]) == Decimal("4500.00")
    assert data["overdue_bills_count"] == 0
    assert data["financial_health_score"] >= 80
    assert data["financial_health_status"] == "Healthy"


def test_advisor_insights_generation(client: TestClient):
    headers = _get_auth_header(client, "insights_advisor@kharcha.ai")
    today = date.today()

    client.post("/api/v1/incomes", json={
        "title": "Salary Income",
        "amount": "80000.00",
        "income_date": str(today)
    }, headers=headers)

    client.post("/api/v1/expenses", json={
        "title": "Groceries",
        "category": "Food",
        "amount": "30000.00",
        "expense_date": str(today)
    }, headers=headers)

    res = client.get("/api/v1/financial-advisor/insights", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert "summary_headline" in data
    assert "provider_used" in data
    assert len(data["insights"]) > 0
    assert "key_recommendation" in data


def test_advisor_chat_affordability(client: TestClient):
    headers = _get_auth_header(client, "chat_afford@kharcha.ai")
    today = date.today()

    # Surplus = 70,000 (Income 120,000 - Expense 50,000)
    client.post("/api/v1/incomes", json={
        "title": "Consulting Revenue",
        "amount": "120000.00",
        "income_date": str(today)
    }, headers=headers)

    client.post("/api/v1/expenses", json={
        "title": "Groceries & Utilities",
        "category": "Food",
        "amount": "50000.00",
        "expense_date": str(today)
    }, headers=headers)

    # 1. Ask about affordable item (40,000 <= 70,000)
    res1 = client.post("/api/v1/financial-advisor/chat", json={
        "message": "Can I afford to buy an office chair for PKR 40,000?"
    }, headers=headers)
    assert res1.status_code == 200
    data1 = res1.json()
    assert "can afford" in data1["reply"].lower() or "surplus" in data1["reply"].lower()
    assert data1["grounded_metrics"]["net_cashflow"] == 70000.0

    # 2. Ask about unaffordable item (200,000 > 70,000)
    res2 = client.post("/api/v1/financial-advisor/chat", json={
        "message": "Can I buy a new motorcycle for PKR 200,000?"
    }, headers=headers)
    assert res2.status_code == 200
    data2 = res2.json()
    assert "strain" in data2["reply"].lower() or "shortfall" in data2["reply"].lower() or "delay" in data2["reply"].lower() or "goal" in data2["reply"].lower()


def test_advisor_chat_savings_and_bills(client: TestClient):
    headers = _get_auth_header(client, "chat_general@kharcha.ai")
    today = date.today()

    client.post("/api/v1/bills", json={
        "title": "Electricity Due",
        "category": "Electricity",
        "amount": "8000.00",
        "due_date": str(today + timedelta(days=2))
    }, headers=headers)

    # Ask about bills
    res_b = client.post("/api/v1/financial-advisor/chat", json={
        "message": "What bills do I have due?"
    }, headers=headers)
    assert res_b.status_code == 200
    assert "bill" in res_b.json()["reply"].lower()

    # Ask about savings
    res_s = client.post("/api/v1/financial-advisor/chat", json={
        "message": "How can I boost my savings rate?"
    }, headers=headers)
    assert res_s.status_code == 200
    assert "savings" in res_s.json()["reply"].lower() or "surplus" in res_s.json()["reply"].lower()


def test_advisor_tenant_isolation(client: TestClient):
    headers_u1 = _get_auth_header(client, "u1_advisor@kharcha.ai")
    headers_u2 = _get_auth_header(client, "u2_advisor@kharcha.ai")
    today = date.today()

    # User 1 has 500,000 income
    client.post("/api/v1/incomes", json={
        "title": "Enterprise Contract",
        "amount": "500000.00",
        "income_date": str(today)
    }, headers=headers_u1)

    # User 2 has 0 income
    u2_overview = client.get("/api/v1/financial-advisor/overview", headers=headers_u2).json()
    assert Decimal(u2_overview["total_income_this_month"]) == Decimal("0.00")
    assert Decimal(u2_overview["net_cashflow"]) == Decimal("0.00")
