from datetime import date, timedelta
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "test_exp_user@kharcha.ai") -> dict:
    """Helper to register and login a user, returning Authorization header."""
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Expense Tester"
    })
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_create_expense_success(client: TestClient):
    """Verify creating a valid expense returns 201 with correct fields."""
    headers = _get_auth_header(client, "create_exp@kharcha.ai")

    payload = {
        "title": "Grocery Shopping",
        "amount": "4500.50",
        "category": "Food",
        "description": "Weekly vegetables and milk",
        "expense_date": str(date.today()),
        "payment_method": "Card"
    }

    response = client.post("/api/v1/expenses", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Grocery Shopping"
    assert data["amount"] == "4500.50"
    assert data["category"] == "Food"
    assert data["payment_method"] == "Card"
    assert data["description"] == "Weekly vegetables and milk"
    assert "id" in data
    assert "user_id" in data


def test_create_expense_validation(client: TestClient):
    """Verify input validation rejects non-positive amount and empty title."""
    headers = _get_auth_header(client, "val_exp@kharcha.ai")

    # Negative amount
    res_neg = client.post("/api/v1/expenses", json={
        "title": "Invalid Amount",
        "amount": "-500.00",
        "category": "Food"
    }, headers=headers)
    assert res_neg.status_code == 422

    # Zero amount
    res_zero = client.post("/api/v1/expenses", json={
        "title": "Zero Amount",
        "amount": "0.00",
        "category": "Food"
    }, headers=headers)
    assert res_zero.status_code == 422

    # Empty title
    res_empty_title = client.post("/api/v1/expenses", json={
        "title": "   ",
        "amount": "100.00",
        "category": "Food"
    }, headers=headers)
    assert res_empty_title.status_code == 422


def test_list_and_filter_expenses(client: TestClient):
    """Verify listing, category filtering, search, and pagination."""
    headers = _get_auth_header(client, "list_exp@kharcha.ai")

    # Seed 3 expenses
    client.post("/api/v1/expenses", json={"title": "Lunch Biryani", "amount": "450.00", "category": "Food"}, headers=headers)
    client.post("/api/v1/expenses", json={"title": "Uber Ride", "amount": "800.00", "category": "Transport"}, headers=headers)
    client.post("/api/v1/expenses", json={"title": "Dinner Pizza", "amount": "1500.00", "category": "Food"}, headers=headers)

    # 1. List all
    res_all = client.get("/api/v1/expenses", headers=headers)
    assert res_all.status_code == 200
    assert res_all.json()["total"] == 3
    assert len(res_all.json()["items"]) == 3

    # 2. Filter by category
    res_cat = client.get("/api/v1/expenses?category=Food", headers=headers)
    assert res_cat.status_code == 200
    assert res_cat.json()["total"] == 2

    # 3. Search query
    res_search = client.get("/api/v1/expenses?search=Uber", headers=headers)
    assert res_search.status_code == 200
    assert res_search.json()["total"] == 1
    assert res_search.json()["items"][0]["title"] == "Uber Ride"


def test_get_update_delete_expense(client: TestClient):
    """Verify single expense CRUD cycle."""
    headers = _get_auth_header(client, "crud_exp@kharcha.ai")

    # Create
    create_res = client.post("/api/v1/expenses", json={
        "title": "Electricity Bill",
        "amount": "8500.00",
        "category": "Bills",
        "payment_method": "Bank Transfer"
    }, headers=headers)
    exp_id = create_res.json()["id"]

    # Retrieve
    get_res = client.get(f"/api/v1/expenses/{exp_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["title"] == "Electricity Bill"

    # Update
    patch_res = client.patch(f"/api/v1/expenses/{exp_id}", json={
        "amount": "9200.00",
        "description": "Including surcharge"
    }, headers=headers)
    assert patch_res.status_code == 200
    assert patch_res.json()["amount"] == "9200.00"
    assert patch_res.json()["description"] == "Including surcharge"

    # Delete
    del_res = client.delete(f"/api/v1/expenses/{exp_id}", headers=headers)
    assert del_res.status_code == 200

    # Ensure deleted
    get_after = client.get(f"/api/v1/expenses/{exp_id}", headers=headers)
    assert get_after.status_code == 404


def test_expense_summary(client: TestClient):
    """Verify aggregated statistics and category breakdown calculation."""
    headers = _get_auth_header(client, "summary_exp@kharcha.ai")

    client.post("/api/v1/expenses", json={"title": "Groceries", "amount": "6000.00", "category": "Food"}, headers=headers)
    client.post("/api/v1/expenses", json={"title": "Petrol", "amount": "4000.00", "category": "Transport"}, headers=headers)

    res = client.get("/api/v1/expenses/summary", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["total_count"] == 2
    assert Decimal(data["total_amount"]) == Decimal("10000.00")
    assert len(data["by_category"]) == 2

    # Check percentages: 6000 is 60%, 4000 is 40%
    cat_map = {c["category"]: c for c in data["by_category"]}
    assert cat_map["Food"]["percentage"] == 60.0
    assert cat_map["Transport"]["percentage"] == 40.0


def test_multi_user_isolation_security(client: TestClient):
    """
    CRITICAL SECURITY TEST:
    Verify that User B CANNOT read, edit, delete, or aggregate User A's expenses.
    """
    headers_user_a = _get_auth_header(client, "user_a@kharcha.ai")
    headers_user_b = _get_auth_header(client, "user_b@kharcha.ai")

    # User A creates a confidential expense
    res_create = client.post("/api/v1/expenses", json={
        "title": "User A Private Salary Bonus Expense",
        "amount": "50000.00",
        "category": "Shopping"
    }, headers=headers_user_a)
    user_a_exp_id = res_create.json()["id"]

    # 1. User B attempts to read User A's expense -> MUST return 404
    res_b_get = client.get(f"/api/v1/expenses/{user_a_exp_id}", headers=headers_user_b)
    assert res_b_get.status_code == 404

    # 2. User B attempts to modify User A's expense -> MUST return 404
    res_b_patch = client.patch(f"/api/v1/expenses/{user_a_exp_id}", json={
        "amount": "1.00"
    }, headers=headers_user_b)
    assert res_b_patch.status_code == 404

    # 3. User B attempts to delete User A's expense -> MUST return 404
    res_b_del = client.delete(f"/api/v1/expenses/{user_a_exp_id}", headers=headers_user_b)
    assert res_b_del.status_code == 404

    # 4. User B lists expenses -> User A's expense is NOT present
    res_b_list = client.get("/api/v1/expenses", headers=headers_user_b)
    assert res_b_list.status_code == 200
    assert res_b_list.json()["total"] == 0
    assert len(res_b_list.json()["items"]) == 0

    # 5. User B summary -> total is 0.00
    res_b_summary = client.get("/api/v1/expenses/summary", headers=headers_user_b)
    assert res_b_summary.status_code == 200
    assert Decimal(res_b_summary.json()["total_amount"]) == Decimal("0.00")
    assert res_b_summary.json()["total_count"] == 0


def test_unauthenticated_expense_access_denied(client: TestClient):
    """Verify all expense routes reject unauthenticated requests with 401."""
    assert client.get("/api/v1/expenses").status_code == 401
    assert client.post("/api/v1/expenses", json={"title": "Test", "amount": "100.00", "category": "Food"}).status_code == 401
    assert client.get("/api/v1/expenses/summary").status_code == 401
    assert client.get("/api/v1/expenses/1").status_code == 401
    assert client.patch("/api/v1/expenses/1", json={"amount": "200.00"}).status_code == 401
    assert client.delete("/api/v1/expenses/1").status_code == 401
