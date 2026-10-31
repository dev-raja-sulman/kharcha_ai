from datetime import date
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "curr_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Currency Tester"
    })
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_list_supported_currencies(client: TestClient):
    res = client.get("/api/v1/currencies")
    assert res.status_code == 200
    data = res.json()
    assert data["base_currency"] == "PKR"
    codes = [c["code"] for c in data["currencies"]]
    for expected in ["PKR", "USD", "EUR", "GBP", "AED", "SAR", "INR", "CAD", "AUD"]:
        assert expected in codes


def test_get_exchange_rates(client: TestClient):
    res = client.get("/api/v1/currencies/rates")
    assert res.status_code == 200
    data = res.json()
    assert len(data["rates"]) >= 16


def test_convert_currency_endpoint(client: TestClient):
    res = client.post("/api/v1/currencies/convert", json={
        "amount": "100.00",
        "from_currency": "USD",
        "to_currency": "PKR"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["original_amount"] == "100.00"
    assert data["original_currency"] == "USD"
    assert data["target_currency"] == "PKR"
    assert Decimal(data["converted_amount"]) == Decimal("27850.00")
    assert data["is_converted"] is True
    assert "Converted from USD 100.00 to PKR 27,850.00" in data["label"]


def test_user_update_preferred_currency(client: TestClient):
    headers = _get_auth_header(client, "pref_curr@kharcha.ai")

    # Check default is PKR
    me_res = client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 200
    assert me_res.json()["preferred_currency"] == "PKR"

    # Update to USD
    up_res = client.put("/api/v1/auth/currency", json={"currency": "USD"}, headers=headers)
    assert up_res.status_code == 200
    assert up_res.json()["preferred_currency"] == "USD"

    # Verify persistence
    me_res2 = client.get("/api/v1/auth/me", headers=headers)
    assert me_res2.json()["preferred_currency"] == "USD"

    # Invalid currency rejected with 400
    bad_res = client.put("/api/v1/auth/currency", json={"currency": "XYZ"}, headers=headers)
    assert bad_res.status_code == 400


def test_patch_user_profile_currency(client: TestClient):
    headers = _get_auth_header(client, "patch_profile@kharcha.ai")

    # Patch preferred currency via /api/v1/auth/me
    patch_res = client.patch(
        "/api/v1/auth/me",
        json={"preferred_currency": "EUR", "full_name": "Euro User"},
        headers=headers
    )
    assert patch_res.status_code == 200
    data = patch_res.json()
    assert data["preferred_currency"] == "EUR"
    assert data["full_name"] == "Euro User"


def test_historical_transactions_currencies_preserved_on_user_preference_change(client: TestClient):
    headers = _get_auth_header(client, "preserve_curr@kharcha.ai")

    # Create expense in PKR
    exp_res = client.post("/api/v1/expenses", json={
        "title": "Historical Dinner",
        "amount": "5000.00",
        "currency": "PKR",
        "category": "Food",
        "expense_date": "2026-10-15"
    }, headers=headers)
    assert exp_res.status_code == 201
    exp_id = exp_res.json()["id"]

    # Create income in USD
    inc_res = client.post("/api/v1/incomes", json={
        "title": "US Freelance Gig",
        "amount": "200.00",
        "currency": "USD",
        "income_date": "2026-10-10"
    }, headers=headers)
    assert inc_res.status_code == 201
    inc_id = inc_res.json()["id"]

    # Change user display currency to GBP
    client.put("/api/v1/auth/currency", json={"currency": "GBP"}, headers=headers)

    # Verify expense still stores original PKR and 5000.00
    exp_check = client.get(f"/api/v1/expenses/{exp_id}", headers=headers)
    assert exp_check.status_code == 200
    assert exp_check.json()["currency"] == "PKR"
    assert Decimal(exp_check.json()["amount"]) == Decimal("5000.00")

    # Verify income still stores original USD and 200.00
    inc_check = client.get(f"/api/v1/incomes/{inc_id}", headers=headers)
    assert inc_check.status_code == 200
    assert inc_check.json()["currency"] == "USD"
    assert Decimal(inc_check.json()["amount"]) == Decimal("200.00")


def test_october_2026_deficit_scenario_exact_warning(client: TestClient):
    """
    Exact scenario from specification:
    Selected month: October 2026
    Income: PKR 50,000
    Expenses: PKR 92,020
    Net Cashflow: -PKR 42,020
    Expected warning: "Your expenses exceed your income by PKR 42,020 this month."
    """
    headers = _get_auth_header(client, "oct2026_deficit@kharcha.ai")

    # 1. Log Income PKR 50,000
    inc_res = client.post("/api/v1/incomes", json={
        "title": "October Salary",
        "amount": "50000.00",
        "currency": "PKR",
        "income_date": "2026-10-01"
    }, headers=headers)
    assert inc_res.status_code == 201

    # 2. Log Expenses totaling PKR 92,020
    exp1_res = client.post("/api/v1/expenses", json={
        "title": "House Rent October",
        "amount": "60000.00",
        "currency": "PKR",
        "category": "Rent",
        "expense_date": "2026-10-05"
    }, headers=headers)
    assert exp1_res.status_code == 201

    exp2_res = client.post("/api/v1/expenses", json={
        "title": "Groceries & Utilities",
        "amount": "32020.00",
        "currency": "PKR",
        "category": "Bills",
        "expense_date": "2026-10-18"
    }, headers=headers)
    assert exp2_res.status_code == 201

    # 3. Retrieve Cashflow Overview for October 2026
    res = client.get("/api/v1/analytics/cashflow?month=10&year=2026", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert data["month"] == 10
    assert data["year"] == 2026
    assert data["currency"] == "PKR"
    assert Decimal(str(data["total_income"])) == Decimal("50000.00")
    assert Decimal(str(data["total_expenses"])) == Decimal("92020.00")
    assert Decimal(str(data["net_cashflow"])) == Decimal("-42020.00")
    assert data["health_status"] == "deficit"

    # Verify exact warning statement
    expected_warning = "Your expenses exceed your income by PKR 42,020 this month."
    assert expected_warning in data["health_summary"]


def test_mixed_currency_cashflow_and_summary_protection(client: TestClient):
    """
    Never blindly sum mismatched currencies.
    Convert using stored exchange rates into user's preferred currency,
    and supply by_currency breakdown of raw amounts.
    """
    headers = _get_auth_header(client, "mixed_curr@kharcha.ai")

    # Add expense in PKR: 2,000
    client.post("/api/v1/expenses", json={
        "title": "Local Meal",
        "amount": "2000.00",
        "currency": "PKR",
        "category": "Food",
        "expense_date": "2026-10-10"
    }, headers=headers)

    # Add expense in USD: 10.00 (rate 278.50 -> 2,785.00 PKR)
    client.post("/api/v1/expenses", json={
        "title": "Online Subscription",
        "amount": "10.00",
        "currency": "USD",
        "category": "Shopping",
        "expense_date": "2026-10-11"
    }, headers=headers)

    # In PKR summary: total must be 2000 + 2785 = 4785, NEVER 2010!
    res = client.get("/api/v1/expenses/summary?start_date=2026-10-01&end_date=2026-10-31", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert Decimal(str(data["total_amount"])) == Decimal("4785.00")
    assert Decimal(str(data["total_amount"])) != Decimal("2010.00")
    assert data["by_currency"]["PKR"] == 2000.0
    assert data["by_currency"]["USD"] == 10.0

