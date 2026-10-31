from datetime import date, timedelta
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "bill_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Bill Tester"
    })
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_unauthenticated_bill_access_denied(client: TestClient):
    assert client.get("/api/v1/bills").status_code == 401
    assert client.post("/api/v1/bills", json={"title": "Internet", "amount": "4500"}).status_code == 401
    assert client.get("/api/v1/bills/summary").status_code == 401
    assert client.get("/api/v1/bills/upcoming").status_code == 401
    assert client.get("/api/v1/bills/1").status_code == 401
    assert client.put("/api/v1/bills/1", json={"title": "Internet Updated"}).status_code == 401
    assert client.delete("/api/v1/bills/1").status_code == 401
    assert client.post("/api/v1/bills/1/mark-paid").status_code == 401


def test_create_bill_success(client: TestClient):
    headers = _get_auth_header(client, "create_bill@kharcha.ai")
    due_d = date.today() + timedelta(days=7)

    res = client.post("/api/v1/bills", json={
        "title": "LESCO Electricity",
        "category": "Electricity",
        "amount": "14850.50",
        "due_date": str(due_d),
        "frequency": "monthly",
        "reminder_enabled": True
    }, headers=headers)

    assert res.status_code == 201
    data = res.json()
    assert data["title"] == "LESCO Electricity"
    assert data["category"] == "Electricity"
    assert Decimal(data["amount"]) == Decimal("14850.50")
    assert data["status"] == "unpaid"
    assert data["is_overdue"] is False
    assert data["linked_expense_id"] is None
    assert "id" in data


def test_create_bill_validation(client: TestClient):
    headers = _get_auth_header(client, "val_bill@kharcha.ai")

    # Negative amount
    res1 = client.post("/api/v1/bills", json={
        "title": "Internet",
        "amount": "-500.00",
        "due_date": str(date.today())
    }, headers=headers)
    assert res1.status_code == 422

    # Empty title
    res2 = client.post("/api/v1/bills", json={
        "title": "   ",
        "amount": "2500.00",
        "due_date": str(date.today())
    }, headers=headers)
    assert res2.status_code == 422


def test_list_bills_and_filters(client: TestClient):
    headers = _get_auth_header(client, "list_bill@kharcha.ai")
    today = date.today()

    client.post("/api/v1/bills", json={
        "title": "Fiber Net",
        "category": "Internet",
        "amount": "4000.00",
        "due_date": str(today + timedelta(days=5))
    }, headers=headers)

    client.post("/api/v1/bills", json={
        "title": "SNGPL Gas",
        "category": "Gas",
        "amount": "2500.00",
        "due_date": str(today - timedelta(days=2))  # Overdue
    }, headers=headers)

    # All bills
    res_all = client.get("/api/v1/bills", headers=headers)
    assert res_all.status_code == 200
    all_data = res_all.json()
    assert all_data["total"] == 2
    assert Decimal(all_data["total_amount"]) == Decimal("6500.00")

    # Filter by overdue
    res_overdue = client.get("/api/v1/bills?status=overdue", headers=headers)
    assert res_overdue.status_code == 200
    overdue_items = res_overdue.json()["items"]
    assert len(overdue_items) == 1
    assert overdue_items[0]["title"] == "SNGPL Gas"
    assert overdue_items[0]["is_overdue"] is True

    # Filter by category
    res_cat = client.get("/api/v1/bills?category=Internet", headers=headers)
    assert res_cat.status_code == 200
    cat_items = res_cat.json()["items"]
    assert len(cat_items) == 1
    assert cat_items[0]["title"] == "Fiber Net"


def test_upcoming_bills_and_summary(client: TestClient):
    headers = _get_auth_header(client, "summary_bill@kharcha.ai")
    today = date.today()

    # 1. Due in 3 days (within upcoming 14 days)
    client.post("/api/v1/bills", json={
        "title": "Water Utility",
        "category": "Water",
        "amount": "1200.00",
        "due_date": str(today + timedelta(days=3))
    }, headers=headers)

    # 2. Due in 30 days (outside upcoming 14 days)
    client.post("/api/v1/bills", json={
        "title": "Annual Gym",
        "category": "Fitness",
        "amount": "30000.00",
        "due_date": str(today + timedelta(days=30))
    }, headers=headers)

    # Check upcoming
    res_up = client.get("/api/v1/bills/upcoming?days=14", headers=headers)
    assert res_up.status_code == 200
    up_items = res_up.json()
    assert len(up_items) == 1
    assert up_items[0]["title"] == "Water Utility"

    # Check summary
    res_sum = client.get("/api/v1/bills/summary", headers=headers)
    assert res_sum.status_code == 200
    summary = res_sum.json()
    assert summary["pending_count"] == 2
    assert Decimal(summary["total_pending_amount"]) == Decimal("31200.00")
    assert summary["overdue_count"] == 0
    assert len(summary["upcoming_bills"]) == 1


def test_mark_bill_paid_with_expense_sync(client: TestClient):
    headers = _get_auth_header(client, "sync_bill@kharcha.ai")
    today = date.today()

    # Create bill
    create_res = client.post("/api/v1/bills", json={
        "title": "Nayatel Fiber",
        "category": "Internet",
        "amount": "5200.00",
        "due_date": str(today + timedelta(days=4))
    }, headers=headers)
    bill_id = create_res.json()["id"]

    # Mark as paid with create_expense=True
    paid_res = client.post(f"/api/v1/bills/{bill_id}/mark-paid", json={
        "paid_date": str(today),
        "create_expense": True,
        "payment_method": "JazzCash"
    }, headers=headers)
    assert paid_res.status_code == 200
    paid_data = paid_res.json()
    assert paid_data["status"] == "paid"
    assert paid_data["paid_date"] == str(today)
    linked_expense_id = paid_data["linked_expense_id"]
    assert linked_expense_id is not None

    # Verify that the expense actually exists in expenses API
    exp_res = client.get(f"/api/v1/expenses/{linked_expense_id}", headers=headers)
    assert exp_res.status_code == 200
    exp_data = exp_res.json()
    assert exp_data["title"] == "Bill: Nayatel Fiber"
    assert Decimal(exp_data["amount"]) == Decimal("5200.00")
    assert exp_data["category"] == "Bills"
    assert exp_data["payment_method"] == "JazzCash"

    # Re-marking already paid bill is idempotent
    re_paid = client.post(f"/api/v1/bills/{bill_id}/mark-paid", json={
        "create_expense": True
    }, headers=headers)
    assert re_paid.status_code == 200
    assert re_paid.json()["linked_expense_id"] == linked_expense_id


def test_mark_bill_paid_without_expense_sync(client: TestClient):
    headers = _get_auth_header(client, "nosync_bill@kharcha.ai")
    today = date.today()

    create_res = client.post("/api/v1/bills", json={
        "title": "Apartment Maintenance",
        "category": "Housing",
        "amount": "8000.00",
        "due_date": str(today + timedelta(days=2))
    }, headers=headers)
    bill_id = create_res.json()["id"]

    paid_res = client.post(f"/api/v1/bills/{bill_id}/mark-paid", json={
        "paid_date": str(today),
        "create_expense": False
    }, headers=headers)
    assert paid_res.status_code == 200
    assert paid_res.json()["status"] == "paid"
    assert paid_res.json()["linked_expense_id"] is None


def test_update_and_delete_bill(client: TestClient):
    headers = _get_auth_header(client, "crud_bill@kharcha.ai")
    today = date.today()

    create_res = client.post("/api/v1/bills", json={
        "title": "Mobile Postpaid",
        "category": "Mobile",
        "amount": "2000.00",
        "due_date": str(today + timedelta(days=10))
    }, headers=headers)
    bill_id = create_res.json()["id"]

    # Update
    up_res = client.put(f"/api/v1/bills/{bill_id}", json={
        "amount": "2400.00",
        "title": "Mobile Postpaid VIP"
    }, headers=headers)
    assert up_res.status_code == 200
    assert up_res.json()["title"] == "Mobile Postpaid VIP"
    assert Decimal(up_res.json()["amount"]) == Decimal("2400.00")

    # Delete
    del_res = client.delete(f"/api/v1/bills/{bill_id}", headers=headers)
    assert del_res.status_code == 204

    # Verify not found
    get_res = client.get(f"/api/v1/bills/{bill_id}", headers=headers)
    assert get_res.status_code == 404


def test_bill_tenant_isolation(client: TestClient):
    headers_u1 = _get_auth_header(client, "u1_bill@kharcha.ai")
    headers_u2 = _get_auth_header(client, "u2_bill@kharcha.ai")

    # User 1 creates bill
    res1 = client.post("/api/v1/bills", json={
        "title": "User1 Private Bill",
        "category": "Personal",
        "amount": "15000.00",
        "due_date": str(date.today() + timedelta(days=5))
    }, headers=headers_u1)
    b1_id = res1.json()["id"]

    # User 2 tries to view, update, delete, or mark paid User 1's bill
    assert client.get(f"/api/v1/bills/{b1_id}", headers=headers_u2).status_code == 404
    assert client.put(f"/api/v1/bills/{b1_id}", json={"amount": "1.00"}, headers=headers_u2).status_code == 404
    assert client.delete(f"/api/v1/bills/{b1_id}", headers=headers_u2).status_code == 404
    assert client.post(f"/api/v1/bills/{b1_id}/mark-paid", headers=headers_u2).status_code == 404

    # User 2 list should not contain User 1's bill
    u2_list = client.get("/api/v1/bills", headers=headers_u2).json()
    assert u2_list["total"] == 0
