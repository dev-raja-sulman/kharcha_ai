from datetime import date, timedelta
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "income_user@kharcha.ai") -> dict:
    """Helper to register and login a user, returning Authorization header."""
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Income Tester"
    })
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_unauthenticated_income_access_denied(client: TestClient):
    """Ensure all income endpoints reject unauthenticated requests with 401."""
    assert client.get("/api/v1/incomes").status_code == 401
    assert client.post("/api/v1/incomes", json={"title": "Salary", "amount": "50000"}).status_code == 401
    assert client.get("/api/v1/incomes/summary").status_code == 401
    assert client.get("/api/v1/incomes/1").status_code == 401
    assert client.put("/api/v1/incomes/1", json={"amount": "60000"}).status_code == 401
    assert client.delete("/api/v1/incomes/1").status_code == 401
    assert client.get("/api/v1/income-sources").status_code == 401
    assert client.post("/api/v1/income-sources", json={"name": "Consulting"}).status_code == 401


def test_default_income_sources_seeded(client: TestClient):
    """Verify that default income sources are automatically provided on first query."""
    headers = _get_auth_header(client, "sources_user@kharcha.ai")
    res = client.get("/api/v1/income-sources", headers=headers)
    assert res.status_code == 200
    sources = res.json()
    assert len(sources) >= 6
    names = [s["name"] for s in sources]
    for expected in ["Salary", "Freelance", "Business", "Investments", "Rental Income", "Other Income"]:
        assert expected in names


def test_create_custom_income_source(client: TestClient):
    """Verify creating a custom income source and handling duplicates."""
    headers = _get_auth_header(client, "custom_source@kharcha.ai")
    res = client.post("/api/v1/income-sources", json={
        "name": "Side Hustle",
        "description": "E-commerce store revenue"
    }, headers=headers)
    assert res.status_code == 201
    data = res.json()
    assert data["name"] == "Side Hustle"
    assert data["description"] == "E-commerce store revenue"
    assert data["is_active"] is True

    # Duplicate creation with same name returns 400
    res_dup = client.post("/api/v1/income-sources", json={
        "name": "Side Hustle",
        "description": "Another one"
    }, headers=headers)
    assert res_dup.status_code == 400


def test_create_income_success(client: TestClient):
    """Verify creating a valid income record with source relationship."""
    headers = _get_auth_header(client, "create_inc@kharcha.ai")

    # Get a source id
    sources_res = client.get("/api/v1/income-sources", headers=headers)
    salary_source = next(s for s in sources_res.json() if s["name"] == "Salary")

    payload = {
        "title": "Monthly Software Engineering Salary",
        "amount": "150000.00",
        "currency": "PKR",
        "income_date": str(date.today()),
        "payment_method": "Bank Transfer",
        "description": "October salary credited to bank account",
        "source_id": salary_source["id"]
    }

    res = client.post("/api/v1/incomes", json=payload, headers=headers)
    assert res.status_code == 201
    data = res.json()
    assert data["title"] == "Monthly Software Engineering Salary"
    assert data["amount"] == "150000.00"
    assert data["currency"] == "PKR"
    assert data["source_id"] == salary_source["id"]
    assert data["source_name"] == "Salary"
    assert data["payment_method"] == "Bank Transfer"
    assert "id" in data
    assert "user_id" in data


def test_create_income_validation(client: TestClient):
    """Verify validation rules: negative amount, zero amount, and empty title."""
    headers = _get_auth_header(client, "val_inc@kharcha.ai")

    # Negative amount
    res = client.post("/api/v1/incomes", json={
        "title": "Bonus",
        "amount": "-5000.00"
    }, headers=headers)
    assert res.status_code == 422

    # Zero amount
    res = client.post("/api/v1/incomes", json={
        "title": "Bonus",
        "amount": "0.00"
    }, headers=headers)
    assert res.status_code == 422

    # Empty/whitespace title
    res = client.post("/api/v1/incomes", json={
        "title": "   ",
        "amount": "1000.00"
    }, headers=headers)
    assert res.status_code == 422


def test_list_and_filter_incomes(client: TestClient):
    """Verify listing incomes with pagination, search, and date filters."""
    headers = _get_auth_header(client, "list_inc@kharcha.ai")

    # Create 3 incomes across different dates
    today = date.today()
    client.post("/api/v1/incomes", json={
        "title": "Client Website Design",
        "amount": "40000.00",
        "income_date": str(today - timedelta(days=5)),
        "payment_method": "EasyPaisa"
    }, headers=headers)

    client.post("/api/v1/incomes", json={
        "title": "Stock Dividends",
        "amount": "15000.00",
        "income_date": str(today),
        "payment_method": "Bank Transfer"
    }, headers=headers)

    client.post("/api/v1/incomes", json={
        "title": "Consulting Hourly Rate",
        "amount": "25000.00",
        "income_date": str(today),
        "payment_method": "Card"
    }, headers=headers)

    # 1. Total list
    res = client.get("/api/v1/incomes", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 3
    assert Decimal(data["total_amount"]) == Decimal("80000.00")
    assert len(data["items"]) == 3

    # 2. Search filter
    res_search = client.get("/api/v1/incomes?search=Dividends", headers=headers)
    assert res_search.status_code == 200
    assert res_search.json()["total"] == 1
    assert res_search.json()["items"][0]["title"] == "Stock Dividends"

    # 3. Date range filter
    res_date = client.get(f"/api/v1/incomes?start_date={str(today)}&end_date={str(today)}", headers=headers)
    assert res_date.status_code == 200
    assert res_date.json()["total"] == 2


def test_get_update_delete_income(client: TestClient):
    """Verify single fetch, update, and deletion lifecycle."""
    headers = _get_auth_header(client, "crud_inc@kharcha.ai")

    # Create
    create_res = client.post("/api/v1/incomes", json={
        "title": "AdSense Payout",
        "amount": "12000.00"
    }, headers=headers)
    income_id = create_res.json()["id"]

    # Read single
    get_res = client.get(f"/api/v1/incomes/{income_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["title"] == "AdSense Payout"

    # Update
    update_res = client.put(f"/api/v1/incomes/{income_id}", json={
        "title": "AdSense & Affiliate Payout",
        "amount": "18500.00"
    }, headers=headers)
    assert update_res.status_code == 200
    assert update_res.json()["title"] == "AdSense & Affiliate Payout"
    assert update_res.json()["amount"] == "18500.00"

    # Delete
    del_res = client.delete(f"/api/v1/incomes/{income_id}", headers=headers)
    assert del_res.status_code == 204

    # Fetch after delete returns 404
    assert client.get(f"/api/v1/incomes/{income_id}", headers=headers).status_code == 404


def test_income_summary_aggregations(client: TestClient):
    """Verify monthly summary aggregation, source breakdown percentages, and averages."""
    headers = _get_auth_header(client, "summary_inc@kharcha.ai")

    sources_res = client.get("/api/v1/income-sources", headers=headers)
    salary_source = next(s for s in sources_res.json() if s["name"] == "Salary")
    freelance_source = next(s for s in sources_res.json() if s["name"] == "Freelance")

    # Add Salary: 80,000 (80%)
    client.post("/api/v1/incomes", json={
        "title": "Company Salary",
        "amount": "80000.00",
        "source_id": salary_source["id"],
        "income_date": str(date.today())
    }, headers=headers)

    # Add Freelance: 20,000 (20%)
    client.post("/api/v1/incomes", json={
        "title": "Logo Design Project",
        "amount": "20000.00",
        "source_id": freelance_source["id"],
        "income_date": str(date.today())
    }, headers=headers)

    res = client.get("/api/v1/incomes/summary", headers=headers)
    assert res.status_code == 200
    summary = res.json()
    assert Decimal(summary["total_income"]) == Decimal("100000.00")
    assert summary["total_transactions"] == 2
    assert Decimal(summary["average_income_per_entry"]) == Decimal("50000.00")

    # Verify breakdown
    breakdown = summary["source_breakdown"]
    assert len(breakdown) == 2
    assert breakdown[0]["source_name"] == "Salary"
    assert Decimal(breakdown[0]["total_amount"]) == Decimal("80000.00")
    assert breakdown[0]["percentage"] == 80.0
    assert breakdown[1]["source_name"] == "Freelance"
    assert Decimal(breakdown[1]["total_amount"]) == Decimal("20000.00")
    assert breakdown[1]["percentage"] == 20.0


def test_multi_user_isolation(client: TestClient):
    """Verify User B cannot access, modify, or view User A's income transactions."""
    user1_headers = _get_auth_header(client, "user1_iso@kharcha.ai")
    user2_headers = _get_auth_header(client, "user2_iso@kharcha.ai")

    # User 1 creates an income
    res = client.post("/api/v1/incomes", json={
        "title": "User 1 Private Salary",
        "amount": "99000.00"
    }, headers=user1_headers)
    user1_inc_id = res.json()["id"]


    # User 2 tries to GET User 1's income -> 404
    assert client.get(f"/api/v1/incomes/{user1_inc_id}", headers=user2_headers).status_code == 404

    # User 2 tries to UPDATE User 1's income -> 404
    assert client.put(f"/api/v1/incomes/{user1_inc_id}", json={"amount": "1.00"}, headers=user2_headers).status_code == 404

    # User 2 tries to DELETE User 1's income -> 404
    assert client.delete(f"/api/v1/incomes/{user1_inc_id}", headers=user2_headers).status_code == 404

    # User 2 list should be empty
    u2_list = client.get("/api/v1/incomes", headers=user2_headers).json()
    assert u2_list["total"] == 0
    assert len(u2_list["items"]) == 0
