from datetime import date
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "cashflow_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Cashflow Tester"
    })
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_unauthenticated_cashflow_rejected(client: TestClient):
    assert client.get("/api/v1/analytics/cashflow").status_code == 401


def test_empty_month_cashflow(client: TestClient):
    headers = _get_auth_header(client, "empty_cf@kharcha.ai")
    res = client.get("/api/v1/analytics/cashflow", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert Decimal(data["total_income"]) == Decimal("0.00")
    assert Decimal(data["total_expenses"]) == Decimal("0.00")
    assert Decimal(data["net_cashflow"]) == Decimal("0.00")
    assert data["savings_rate"] == 0.0
    assert data["health_status"] == "no_data"
    assert "No Activity Recorded" in data["health_title"]


def test_positive_cashflow_surplus_and_savings_rate(client: TestClient):
    headers = _get_auth_header(client, "surplus_cf@kharcha.ai")
    today = date.today()

    # Log 100,000 income
    client.post("/api/v1/incomes", json={
        "title": "Monthly Salary",
        "amount": "100000.00",
        "income_date": str(today)
    }, headers=headers)

    # Log 40,000 expense
    client.post("/api/v1/expenses", json={
        "title": "Groceries & Utilities",
        "amount": "40000.00",
        "category": "Food",
        "expense_date": str(today)
    }, headers=headers)

    res = client.get(f"/api/v1/analytics/cashflow?month={today.month}&year={today.year}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert Decimal(data["total_income"]) == Decimal("100000.00")
    assert Decimal(data["total_expenses"]) == Decimal("40000.00")
    assert Decimal(data["net_cashflow"]) == Decimal("60000.00")
    assert data["savings_rate"] == 60.0
    assert data["health_status"] == "surplus"
    assert "Positive Cashflow" in data["health_title"]


def test_deficit_cashflow_alert(client: TestClient):
    headers = _get_auth_header(client, "deficit_cf@kharcha.ai")
    today = date.today()

    # Log 50,000 income
    client.post("/api/v1/incomes", json={
        "title": "Part-Time Income",
        "amount": "50000.00",
        "income_date": str(today)
    }, headers=headers)

    # Log 75,000 expense
    client.post("/api/v1/expenses", json={
        "title": "Major Car Repair",
        "amount": "75000.00",
        "category": "Transport",
        "expense_date": str(today)
    }, headers=headers)

    res = client.get(f"/api/v1/analytics/cashflow?month={today.month}&year={today.year}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert Decimal(data["total_income"]) == Decimal("50000.00")
    assert Decimal(data["total_expenses"]) == Decimal("75000.00")
    assert Decimal(data["net_cashflow"]) == Decimal("-25000.00")
    assert data["savings_rate"] == 0.0
    assert data["health_status"] == "deficit"
    assert "Operating at a Deficit" in data["health_title"]


def test_cashflow_with_budget_comparison(client: TestClient):
    headers = _get_auth_header(client, "budget_cf@kharcha.ai")
    today = date.today()

    # Create monthly budget: 50,000
    client.post("/api/v1/budgets", json={
        "name": "Monthly Budget Limit",
        "amount": "50000.00",
        "month": today.month,
        "year": today.year
    }, headers=headers)

    # Income: 80,000
    client.post("/api/v1/incomes", json={
        "title": "Salary",
        "amount": "80000.00",
        "income_date": str(today)
    }, headers=headers)

    # Expense: 35,000
    client.post("/api/v1/expenses", json={
        "title": "Food & Shopping",
        "amount": "35000.00",
        "category": "Shopping",
        "expense_date": str(today)
    }, headers=headers)

    res = client.get(f"/api/v1/analytics/cashflow?month={today.month}&year={today.year}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert Decimal(data["total_budget"]) == Decimal("50000.00")
    assert Decimal(data["remaining_budget"]) == Decimal("15000.00")
    assert data["budget_used_percentage"] == 70.0


def test_cashflow_multi_user_isolation(client: TestClient):
    user1_headers = _get_auth_header(client, "user1_cf@kharcha.ai")
    user2_headers = _get_auth_header(client, "user2_cf@kharcha.ai")
    today = date.today()

    # User 1 logs income: 120,000
    client.post("/api/v1/incomes", json={
        "title": "User 1 Salary",
        "amount": "120000.00",
        "income_date": str(today)
    }, headers=user1_headers)

    # User 2 cashflow should still be 0.00
    u2_res = client.get(f"/api/v1/analytics/cashflow?month={today.month}&year={today.year}", headers=user2_headers)
    assert u2_res.status_code == 200
    u2_data = u2_res.json()
    assert Decimal(u2_data["total_income"]) == Decimal("0.00")
    assert Decimal(u2_data["total_expenses"]) == Decimal("0.00")
    assert u2_data["health_status"] == "no_data"
