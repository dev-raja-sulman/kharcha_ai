from datetime import date
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "budget_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Budget Tester"
    })
    res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_unauthenticated_budget_access_rejected(client: TestClient):
    """Unauthenticated budget endpoints must be rejected with 401."""
    res_list = client.get("/api/v1/budgets")
    assert res_list.status_code == 401

    res_create = client.post("/api/v1/budgets", json={
        "name": "Unauthorized Budget",
        "amount": "10000.00",
        "month": 10,
        "year": 2026
    })
    assert res_create.status_code == 401


def test_create_overall_and_category_budgets(client: TestClient):
    """Verify creating overall and category budgets with correct date boundaries."""
    headers = _get_auth_header(client, "budget_create@kharcha.ai")

    # 1. Overall Monthly Budget
    res_overall = client.post("/api/v1/budgets", json={
        "name": "October Overall Budget",
        "amount": "50000.00",
        "category": None,
        "month": 10,
        "year": 2026
    }, headers=headers)
    assert res_overall.status_code == 201
    d_overall = res_overall.json()
    assert d_overall["name"] == "October Overall Budget"
    assert d_overall["amount"] == "50000.00"
    assert d_overall["category"] is None
    assert d_overall["start_date"] == "2026-10-01"
    assert d_overall["end_date"] == "2026-10-31"
    assert d_overall["spent"] == "0.00"
    assert d_overall["remaining"] == "50000.00"
    assert d_overall["alert_level"] == "normal"

    # 2. Food Category Budget
    res_food = client.post("/api/v1/budgets", json={
        "name": "Food & Groceries",
        "amount": "15000.00",
        "category": "Food",
        "month": 10,
        "year": 2026
    }, headers=headers)
    assert res_food.status_code == 201
    d_food = res_food.json()
    assert d_food["name"] == "Food & Groceries"
    assert d_food["amount"] == "15000.00"
    assert d_food["category"] == "Food"


def test_budget_validation_and_duplicate_prevention(client: TestClient):
    """Verify rejection of invalid amounts and duplicate budgets for same period/category."""
    headers = _get_auth_header(client, "budget_val@kharcha.ai")

    # Non-positive amount rejected
    res_neg = client.post("/api/v1/budgets", json={
        "name": "Negative Budget",
        "amount": "-500.00",
        "month": 10,
        "year": 2026
    }, headers=headers)
    assert res_neg.status_code == 422

    # Initial valid creation
    res_init = client.post("/api/v1/budgets", json={
        "name": "Transport October",
        "amount": "10000.00",
        "category": "Transport",
        "month": 10,
        "year": 2026
    }, headers=headers)
    assert res_init.status_code == 201

    # Duplicate budget for same category and month rejected
    res_dup = client.post("/api/v1/budgets", json={
        "name": "Transport Second Try",
        "amount": "12000.00",
        "category": "Transport",
        "month": 10,
        "year": 2026
    }, headers=headers)
    assert res_dup.status_code == 400
    assert "already exists" in res_dup.json()["detail"].lower()


def test_budget_spending_and_alert_thresholds(client: TestClient):
    """Verify 50%, 80%, and 100%+ alert levels based on recorded expenses."""
    headers = _get_auth_header(client, "budget_alerts@kharcha.ai")

    # Create category budget: Food = 10,000.00
    res_b = client.post("/api/v1/budgets", json={
        "name": "Dining Budget",
        "amount": "10000.00",
        "category": "Food",
        "month": 10,
        "year": 2026
    }, headers=headers)
    b_id = res_b.json()["id"]

    # 1. Under 50%: spend 3000 -> normal
    client.post("/api/v1/expenses", json={
        "title": "Burger Lunch",
        "amount": "3000.00",
        "category": "Food",
        "expense_date": "2026-10-05"
    }, headers=headers)

    res_check1 = client.get(f"/api/v1/budgets/{b_id}", headers=headers)
    d1 = res_check1.json()
    assert d1["spent"] == "3000.00"
    assert d1["remaining"] == "7000.00"
    assert d1["percentage_used"] == 30.0
    assert d1["alert_level"] == "normal"

    # 2. 50% Threshold: spend another 2500 -> total 5500 (55%) -> warning_50
    client.post("/api/v1/expenses", json={
        "title": "Pizza Dinner",
        "amount": "2500.00",
        "category": "Food",
        "expense_date": "2026-10-10"
    }, headers=headers)

    res_check2 = client.get(f"/api/v1/budgets/{b_id}", headers=headers)
    d2 = res_check2.json()
    assert d2["spent"] == "5500.00"
    assert d2["percentage_used"] == 55.0
    assert d2["alert_level"] == "warning_50"

    # 3. 80% Threshold: spend another 3000 -> total 8500 (85%) -> warning_80
    client.post("/api/v1/expenses", json={
        "title": "Grocery Shopping",
        "amount": "3000.00",
        "category": "Food",
        "expense_date": "2026-10-15"
    }, headers=headers)

    res_check3 = client.get(f"/api/v1/budgets/{b_id}", headers=headers)
    d3 = res_check3.json()
    assert d3["spent"] == "8500.00"
    assert d3["percentage_used"] == 85.0
    assert d3["alert_level"] == "warning_80"

    # 4. 100%+ Exceeded: spend another 2000 -> total 10500 (105%) -> exceeded_100
    client.post("/api/v1/expenses", json={
        "title": "Cafe Snacks",
        "amount": "2000.00",
        "category": "Food",
        "expense_date": "2026-10-20"
    }, headers=headers)

    res_check4 = client.get(f"/api/v1/budgets/{b_id}", headers=headers)
    d4 = res_check4.json()
    assert d4["spent"] == "10500.00"
    assert d4["remaining"] == "-500.00"
    assert d4["percentage_used"] == 105.0
    assert d4["alert_level"] == "exceeded_100"


def test_budget_progress_summary_endpoint(client: TestClient):
    """Verify GET /api/v1/budgets/progress returns active alerts and overall summary."""
    headers = _get_auth_header(client, "budget_summary@kharcha.ai")

    # Create overall budget 20,000 and Food budget 5,000
    client.post("/api/v1/budgets", json={
        "name": "Total Monthly",
        "amount": "20000.00",
        "month": 10,
        "year": 2026
    }, headers=headers)
    client.post("/api/v1/budgets", json={
        "name": "Food Limit",
        "amount": "5000.00",
        "category": "Food",
        "month": 10,
        "year": 2026
    }, headers=headers)

    # Spend 4,500 on Food (90% of Food budget -> triggers warning_80)
    client.post("/api/v1/expenses", json={
        "title": "Supermarket",
        "amount": "4500.00",
        "category": "Food",
        "expense_date": "2026-10-12"
    }, headers=headers)

    res_prog = client.get("/api/v1/budgets/progress?month=10&year=2026", headers=headers)
    assert res_prog.status_code == 200
    p_data = res_prog.json()
    assert p_data["overall_budget"]["amount"] == "20000.00"
    assert p_data["overall_budget"]["spent"] == "4500.00"
    assert len(p_data["category_budgets"]) == 1
    assert len(p_data["active_alerts"]) == 1
    assert p_data["active_alerts"][0]["category"] == "Food"
    assert p_data["active_alerts"][0]["level"] == "warning_80"


def test_budget_multi_user_isolation(client: TestClient):
    """User 2 must not see, edit, or delete User 1's budgets."""
    headers1 = _get_auth_header(client, "user1_budget_iso@kharcha.ai")
    headers2 = _get_auth_header(client, "user2_budget_iso@kharcha.ai")

    # User 1 creates budget
    res1 = client.post("/api/v1/budgets", json={
        "name": "User 1 Secret Budget",
        "amount": "25000.00",
        "month": 10,
        "year": 2026
    }, headers=headers1)
    b1_id = res1.json()["id"]

    # User 2 list should be empty
    res2_list = client.get("/api/v1/budgets?month=10&year=2026", headers=headers2)
    assert res2_list.json()["total"] == 0

    # User 2 cannot GET User 1's budget (404)
    res2_get = client.get(f"/api/v1/budgets/{b1_id}", headers=headers2)
    assert res2_get.status_code == 404

    # User 2 cannot PATCH User 1's budget (404)
    res2_patch = client.patch(f"/api/v1/budgets/{b1_id}", json={"amount": "1.00"}, headers=headers2)
    assert res2_patch.status_code == 404

    # User 2 cannot DELETE User 1's budget (404)
    res2_del = client.delete(f"/api/v1/budgets/{b1_id}", headers=headers2)
    assert res2_del.status_code == 404


def test_update_and_delete_budget(client: TestClient):
    """Verify modifying budget amount/name and deleting."""
    headers = _get_auth_header(client, "budget_mod@kharcha.ai")

    res_c = client.post("/api/v1/budgets", json={
        "name": "Initial Name",
        "amount": "5000.00",
        "month": 10,
        "year": 2026
    }, headers=headers)
    b_id = res_c.json()["id"]

    # Update
    res_up = client.patch(f"/api/v1/budgets/{b_id}", json={
        "name": "Updated Name",
        "amount": "8000.00"
    }, headers=headers)
    assert res_up.status_code == 200
    assert res_up.json()["name"] == "Updated Name"
    assert res_up.json()["amount"] == "8000.00"

    # Delete
    res_del = client.delete(f"/api/v1/budgets/{b_id}", headers=headers)
    assert res_del.status_code == 200

    # Verify deleted
    res_check = client.get(f"/api/v1/budgets/{b_id}", headers=headers)
    assert res_check.status_code == 404
