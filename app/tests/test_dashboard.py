from datetime import date
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "dash_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Dashboard Tester"
    })
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_unauthenticated_dashboard_rejected(client: TestClient):
    assert client.get("/api/v1/dashboard/financial-summary").status_code == 401


def test_never_compare_lifetime_expenses_against_monthly_income(client: TestClient):
    """
    CRITICAL REQUIREMENT:
    Ensure expenses from earlier months do NOT leak into a month with zero expenses.
    """
    headers = _get_auth_header(client, "lifetime_isolation@kharcha.ai")

    # Log 50,000 expense in January 2026
    client.post("/api/v1/expenses", json={
        "title": "January Huge Purchase",
        "amount": "50000.00",
        "category": "Shopping",
        "expense_date": "2026-01-15"
    }, headers=headers)

    # Log 30,000 income in February 2026 (February has 0 expenses)
    client.post("/api/v1/incomes", json={
        "title": "February Salary",
        "amount": "30000.00",
        "income_date": "2026-02-10"
    }, headers=headers)

    # Fetch February 2026 dashboard
    res = client.get("/api/v1/dashboard/financial-summary?month=2&year=2026", headers=headers)
    assert res.status_code == 200
    data = res.json()

    # February expenses MUST BE exactly 0.00, NOT the lifetime 50,000.00!
    assert Decimal(data["summary_cards"]["monthly_income"]) == Decimal("30000.00")
    assert Decimal(data["summary_cards"]["monthly_expenses"]) == Decimal("0.00")
    assert Decimal(data["summary_cards"]["net_cashflow"]) == Decimal("30000.00")
    assert data["summary_cards"]["savings_rate"] == 100.0
    assert data["summary_cards"]["is_deficit"] is False
    assert data["summary_cards"]["deficit_warning_message"] is None


def test_deficit_warning_generation(client: TestClient):
    """
    User's monthly income: PKR 50,000
    User's monthly expenses: PKR 92,020
    Monthly net cashflow: -PKR 42,020
    Warning: "Your expenses exceed your income by PKR 42,020.00 this month."
    """
    headers = _get_auth_header(client, "deficit_user@kharcha.ai")

    # Incur 50,000 income in March 2026
    client.post("/api/v1/incomes", json={
        "title": "March Salary",
        "amount": "50000.00",
        "income_date": "2026-03-01"
    }, headers=headers)

    # Incur 92,020 expenses in March 2026
    client.post("/api/v1/expenses", json={
        "title": "March Rent & Groceries",
        "amount": "92020.00",
        "category": "Rent",
        "expense_date": "2026-03-05"
    }, headers=headers)

    res = client.get("/api/v1/dashboard/financial-summary?month=3&year=2026", headers=headers)
    assert res.status_code == 200
    data = res.json()

    cards = data["summary_cards"]
    assert Decimal(cards["monthly_income"]) == Decimal("50000.00")
    assert Decimal(cards["monthly_expenses"]) == Decimal("92020.00")
    assert Decimal(cards["net_cashflow"]) == Decimal("-42020.00")
    assert cards["savings_rate"] == 0.0
    assert cards["is_deficit"] is True
    assert "Your expenses exceed your income by PKR 42,020.00 this month." in cards["deficit_warning_message"]


def test_dashboard_multi_currency_conversion(client: TestClient):
    """
    Verify transactions logged in different currencies are converted to display currency.
    User preferred currency = PKR.
    Log 100 USD income (should convert to 27,850 PKR @ 278.50).
    Log 10,000 PKR expense.
    Net surplus = 27,850 - 10,000 = 17,850 PKR.
    """
    headers = _get_auth_header(client, "multicurrency_dash@kharcha.ai")

    client.post("/api/v1/incomes", json={
        "title": "Remote Freelance Project",
        "amount": "100.00",
        "currency": "USD",
        "income_date": "2026-04-10"
    }, headers=headers)

    client.post("/api/v1/expenses", json={
        "title": "Local Internet Bill",
        "amount": "10000.00",
        "currency": "PKR",
        "category": "Bills",
        "expense_date": "2026-04-12"
    }, headers=headers)

    res = client.get("/api/v1/dashboard/financial-summary?month=4&year=2026", headers=headers)
    assert res.status_code == 200
    data = res.json()

    cards = data["summary_cards"]
    assert Decimal(cards["monthly_income"]) == Decimal("27850.00")
    assert Decimal(cards["monthly_expenses"]) == Decimal("10000.00")
    assert Decimal(cards["net_cashflow"]) == Decimal("17850.00")
    assert data["currency"] == "PKR"
