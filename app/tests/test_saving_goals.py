from datetime import date, timedelta
from decimal import Decimal
import pytest
from fastapi.testclient import TestClient


def _get_auth_header(client: TestClient, email: str = "goal_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Goal Tester"
    })
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_unauthenticated_saving_goal_access_denied(client: TestClient):
    assert client.get("/api/v1/saving-goals").status_code == 401
    assert client.post("/api/v1/saving-goals", json={"title": "Laptop", "target_amount": "150000"}).status_code == 401
    assert client.get("/api/v1/saving-goals/1").status_code == 401
    assert client.put("/api/v1/saving-goals/1", json={"title": "New Laptop"}).status_code == 401
    assert client.delete("/api/v1/saving-goals/1").status_code == 401
    assert client.post("/api/v1/saving-goals/1/contributions", json={"amount": "5000"}).status_code == 401
    assert client.get("/api/v1/saving-goals/1/contributions").status_code == 401


def test_create_saving_goal_success(client: TestClient):
    headers = _get_auth_header(client, "create_goal@kharcha.ai")
    today = date.today()
    target_d = today + timedelta(days=90)

    res = client.post("/api/v1/saving-goals", json={
        "title": "Buy MacBook M3 Pro",
        "description": "For mobile app development and AI engineering",
        "target_amount": "350000.00",
        "start_date": str(today),
        "target_date": str(target_d)
    }, headers=headers)

    assert res.status_code == 201
    data = res.json()
    assert data["title"] == "Buy MacBook M3 Pro"
    assert Decimal(data["target_amount"]) == Decimal("350000.00")
    assert Decimal(data["current_amount"]) == Decimal("0.00")
    assert Decimal(data["remaining_amount"]) == Decimal("350000.00")
    assert data["progress_percentage"] == 0.0
    assert data["status"] == "in_progress"
    assert "id" in data


def test_create_saving_goal_validation(client: TestClient):
    headers = _get_auth_header(client, "val_goal@kharcha.ai")
    today = date.today()

    # Negative amount
    res1 = client.post("/api/v1/saving-goals", json={
        "title": "Emergency Fund",
        "target_amount": "-50000.00",
        "target_date": str(today + timedelta(days=30))
    }, headers=headers)
    assert res1.status_code == 422

    # Blank title
    res2 = client.post("/api/v1/saving-goals", json={
        "title": "   ",
        "target_amount": "50000.00",
        "target_date": str(today + timedelta(days=30))
    }, headers=headers)
    assert res2.status_code == 422

    # Target date before start date
    res3 = client.post("/api/v1/saving-goals", json={
        "title": "Past Goal",
        "target_amount": "50000.00",
        "start_date": str(today),
        "target_date": str(today - timedelta(days=5))
    }, headers=headers)
    assert res3.status_code == 422


def test_add_contribution_atomic_balance(client: TestClient):
    headers = _get_auth_header(client, "contrib_goal@kharcha.ai")
    today = date.today()

    # Create Goal: PKR 150,000
    create_res = client.post("/api/v1/saving-goals", json={
        "title": "Buy a Laptop",
        "target_amount": "150000.00",
        "target_date": str(today + timedelta(days=60))
    }, headers=headers)
    goal_id = create_res.json()["id"]

    # Contribution 1: PKR 30,000
    c1_res = client.post(f"/api/v1/saving-goals/{goal_id}/contributions", json={
        "amount": "30000.00",
        "notes": "First savings allocation from freelance gig"
    }, headers=headers)
    assert c1_res.status_code == 201

    # Verify Goal state: Current: 30,000, Remaining: 120,000, Progress: 20%
    goal1 = client.get(f"/api/v1/saving-goals/{goal_id}", headers=headers).json()
    assert Decimal(goal1["current_amount"]) == Decimal("30000.00")
    assert Decimal(goal1["remaining_amount"]) == Decimal("120000.00")
    assert goal1["progress_percentage"] == 20.0
    assert goal1["status"] == "in_progress"

    # Contribution 2: PKR 120,000 -> Goal Completed!
    c2_res = client.post(f"/api/v1/saving-goals/{goal_id}/contributions", json={
        "amount": "120000.00",
        "notes": "Salary bonus contribution"
    }, headers=headers)
    assert c2_res.status_code == 201

    # Verify Goal state: Current: 150,000, Remaining: 0, Progress: 100%, Status: completed
    goal2 = client.get(f"/api/v1/saving-goals/{goal_id}", headers=headers).json()
    assert Decimal(goal2["current_amount"]) == Decimal("150000.00")
    assert Decimal(goal2["remaining_amount"]) == Decimal("0.00")
    assert goal2["progress_percentage"] == 100.0
    assert goal2["status"] == "completed"

    # Check contributions history list
    history_res = client.get(f"/api/v1/saving-goals/{goal_id}/contributions", headers=headers)
    assert history_res.status_code == 200
    history = history_res.json()
    assert len(history) == 2


def test_update_and_delete_saving_goal(client: TestClient):
    headers = _get_auth_header(client, "update_goal@kharcha.ai")
    today = date.today()

    res = client.post("/api/v1/saving-goals", json={
        "title": "Vacation Trip",
        "target_amount": "80000.00",
        "target_date": str(today + timedelta(days=45))
    }, headers=headers)
    goal_id = res.json()["id"]

    # Add 20,000 contribution
    client.post(f"/api/v1/saving-goals/{goal_id}/contributions", json={
        "amount": "20000.00"
    }, headers=headers)

    # Try lowering target_amount below 20,000 -> Rejected with 400
    res_bad_target = client.put(f"/api/v1/saving-goals/{goal_id}", json={
        "target_amount": "10000.00"
    }, headers=headers)
    assert res_bad_target.status_code == 400

    # Valid update
    res_up = client.put(f"/api/v1/saving-goals/{goal_id}", json={
        "title": "Northern Areas Trip",
        "target_amount": "100000.00"
    }, headers=headers)
    assert res_up.status_code == 200
    assert res_up.json()["title"] == "Northern Areas Trip"
    assert Decimal(res_up.json()["target_amount"]) == Decimal("100000.00")

    # Delete goal
    del_res = client.delete(f"/api/v1/saving-goals/{goal_id}", headers=headers)
    assert del_res.status_code == 204
    assert client.get(f"/api/v1/saving-goals/{goal_id}", headers=headers).status_code == 404


def test_saving_goals_multi_user_isolation(client: TestClient):
    user1_headers = _get_auth_header(client, "user1_goal@kharcha.ai")
    user2_headers = _get_auth_header(client, "user2_goal@kharcha.ai")
    today = date.today()

    # User 1 creates goal
    u1_goal = client.post("/api/v1/saving-goals", json={
        "title": "Private Secret Goal",
        "target_amount": "500000.00",
        "target_date": str(today + timedelta(days=180))
    }, headers=user1_headers).json()
    u1_id = u1_goal["id"]

    # User 2 cannot read, contribute to, update, or delete User 1's goal
    assert client.get(f"/api/v1/saving-goals/{u1_id}", headers=user2_headers).status_code == 404
    assert client.post(f"/api/v1/saving-goals/{u1_id}/contributions", json={"amount": "1000.00"}, headers=user2_headers).status_code == 404
    assert client.put(f"/api/v1/saving-goals/{u1_id}", json={"title": "Hacked"}, headers=user2_headers).status_code == 404
    assert client.delete(f"/api/v1/saving-goals/{u1_id}", headers=user2_headers).status_code == 404

    # User 2 list is empty
    u2_list = client.get("/api/v1/saving-goals", headers=user2_headers).json()
    assert u2_list["total"] == 0
    assert len(u2_list["items"]) == 0
