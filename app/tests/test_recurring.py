from datetime import date, timedelta
from decimal import Decimal
import pytest
from app.models.recurring_expense import RecurringExpense
from app.services.recurring_service import RecurringService


def get_auth_token(client, email="recurring_user@test.com", password="SecurePassword123!"):
    resp = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": password,
        "full_name": "Recurring Tester"
    })
    if resp.status_code == 201:
        return resp.json()["access_token"]
    login_resp = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return login_resp.json()["access_token"]


def test_create_recurring_rules_all_frequencies(client):
    token = get_auth_token(client, "user_freq@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    frequencies = ["daily", "weekly", "monthly", "yearly"]
    for freq in frequencies:
        resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
            "title": f"Test {freq.title()} Subscription",
            "amount": 2500.50,
            "category": "Bills",
            "frequency": freq,
            "description": f"Recurring bill for {freq}",
            "payment_method": "Card"
        })
        assert resp.status_code == 201
        data = resp.json()
        assert data["title"] == f"Test {freq.title()} Subscription"
        assert Decimal(str(data["amount"])) == Decimal("2500.50")
        assert data["frequency"] == freq
        assert data["status"] == "active"
        assert data["next_scheduled_date"] == date.today().isoformat()


def test_recurring_date_calculation_units():
    # 1. Daily
    d1 = date(2026, 1, 15)
    assert RecurringService.calculate_next_date(d1, "daily") == date(2026, 1, 16)

    # 2. Weekly
    assert RecurringService.calculate_next_date(d1, "weekly") == date(2026, 1, 22)

    # 3. Monthly normal
    assert RecurringService.calculate_next_date(d1, "monthly") == date(2026, 2, 15)

    # 4. Monthly month-end clamping (Jan 31 -> Feb 28 in non-leap year)
    d_jan31 = date(2025, 1, 31)
    assert RecurringService.calculate_next_date(d_jan31, "monthly") == date(2025, 2, 28)

    # 5. Monthly year rollover (Dec 15 -> Jan 15 next year)
    d_dec15 = date(2026, 12, 15)
    assert RecurringService.calculate_next_date(d_dec15, "monthly") == date(2027, 1, 15)

    # 6. Yearly normal
    assert RecurringService.calculate_next_date(d1, "yearly") == date(2027, 1, 15)

    # 7. Yearly leap-year (Feb 29, 2024 -> Feb 28, 2025)
    d_leap = date(2024, 2, 29)
    assert RecurringService.calculate_next_date(d_leap, "yearly") == date(2025, 2, 28)


def test_create_recurring_rule_validation(client):
    token = get_auth_token(client, "val_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    # Zero or negative amount
    resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "Invalid Amount",
        "amount": 0,
        "category": "Bills",
        "frequency": "monthly"
    })
    assert resp.status_code == 422

    # End date before start date
    resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "Invalid Dates",
        "amount": 1000,
        "category": "Bills",
        "frequency": "monthly",
        "start_date": "2026-06-01",
        "end_date": "2026-05-01"
    })
    assert resp.status_code == 422

    # Invalid frequency
    resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "Invalid Freq",
        "amount": 1000,
        "category": "Bills",
        "frequency": "biweekly"
    })
    assert resp.status_code == 422


def test_pause_resume_cancel_rule(client):
    token = get_auth_token(client, "lifecycle_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    create_resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "Gym Membership",
        "amount": 5000.00,
        "category": "Healthcare",
        "frequency": "monthly"
    })
    rule_id = create_resp.json()["id"]

    # Pause
    pause_resp = client.post(f"/api/v1/recurring-expenses/{rule_id}/pause", headers=headers)
    assert pause_resp.status_code == 200
    assert pause_resp.json()["status"] == "paused"

    # Resume
    resume_resp = client.post(f"/api/v1/recurring-expenses/{rule_id}/resume", headers=headers)
    assert resume_resp.status_code == 200
    assert resume_resp.json()["status"] == "active"

    # Cancel
    cancel_resp = client.post(f"/api/v1/recurring-expenses/{rule_id}/cancel", headers=headers)
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["status"] == "cancelled"

    # Attempt to pause or resume cancelled rule should fail
    resp2 = client.post(f"/api/v1/recurring-expenses/{rule_id}/pause", headers=headers)
    assert resp2.status_code == 400


def test_idempotent_processing_and_duplicate_prevention(client, db_session):
    token = get_auth_token(client, "idem_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    # Create daily recurring rule starting today
    today = date.today()
    create_resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "Daily Newspaper",
        "amount": 50.00,
        "category": "Bills",
        "frequency": "daily",
        "start_date": today.isoformat()
    })
    rule_id = create_resp.json()["id"]

    # Process due expenses - 1st time
    proc1 = client.post("/api/v1/recurring-expenses/process", headers=headers)
    assert proc1.status_code == 200
    assert proc1.json()["generated_count"] == 1

    # Verify expense was created
    history_resp = client.get(f"/api/v1/recurring-expenses/{rule_id}/history", headers=headers)
    assert history_resp.status_code == 200
    history = history_resp.json()
    assert len(history) == 1
    assert Decimal(str(history[0]["amount"])) == Decimal("50.00")
    assert history[0]["expense_date"] == today.isoformat()

    # Process due expenses - 2nd time immediately (Idempotency verification)
    proc2 = client.post("/api/v1/recurring-expenses/process", headers=headers)
    assert proc2.status_code == 200
    assert proc2.json()["generated_count"] == 0  # No duplicates created!

    # Verify history still has only 1 expense
    history_resp2 = client.get(f"/api/v1/recurring-expenses/{rule_id}/history", headers=headers)
    assert len(history_resp2.json()) == 1


def test_end_date_boundary_stops_generation(client):
    token = get_auth_token(client, "boundary_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    today = date.today()
    # Create rule with end_date = today
    create_resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "One-Day Pass",
        "amount": 300.00,
        "category": "Entertainment",
        "frequency": "daily",
        "start_date": today.isoformat(),
        "end_date": today.isoformat()
    })
    rule_id = create_resp.json()["id"]

    # Process
    proc = client.post("/api/v1/recurring-expenses/process", headers=headers)
    assert proc.json()["generated_count"] == 1

    # Rule should now be marked completed because next_date would exceed end_date
    rule_info = client.get(f"/api/v1/recurring-expenses/{rule_id}", headers=headers).json()
    assert rule_info["status"] == "completed"

    # Processing again does nothing
    proc2 = client.post("/api/v1/recurring-expenses/process", headers=headers)
    assert proc2.json()["generated_count"] == 0


def test_cross_user_isolation(client):
    token_a = get_auth_token(client, "user_a@test.com")
    token_b = get_auth_token(client, "user_b@test.com")

    # User A creates rule
    rule_a = client.post(
        "/api/v1/recurring-expenses",
        headers={"Authorization": f"Bearer {token_a}"},
        json={
            "title": "User A Private Net",
            "amount": 2000.00,
            "category": "Bills",
            "frequency": "monthly"
        }
    ).json()

    # User B tries to view, pause, or cancel User A's rule
    get_resp = client.get(
        f"/api/v1/recurring-expenses/{rule_a['id']}",
        headers={"Authorization": f"Bearer {token_b}"}
    )
    assert get_resp.status_code == 404

    pause_resp = client.post(
        f"/api/v1/recurring-expenses/{rule_a['id']}/pause",
        headers={"Authorization": f"Bearer {token_b}"}
    )
    assert pause_resp.status_code == 404


def test_future_start_date_not_prematurely_generated(client):
    token = get_auth_token(client, "future_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    tomorrow = date.today() + timedelta(days=1)
    create_resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "Future Streaming Service",
        "amount": 1500.00,
        "category": "Entertainment",
        "frequency": "monthly",
        "start_date": tomorrow.isoformat()
    })
    assert create_resp.status_code == 201
    rule_data = create_resp.json()
    assert rule_data["next_scheduled_date"] == tomorrow.isoformat()

    # Process due expenses as of today: 0 should be generated
    proc = client.post("/api/v1/recurring-expenses/process", headers=headers)
    assert proc.status_code == 200
    assert proc.json()["generated_count"] == 0

    # Rule history should be empty
    history = client.get(f"/api/v1/recurring-expenses/{rule_data['id']}/history", headers=headers).json()
    assert len(history) == 0


def test_update_recurring_rule_and_validation(client):
    token = get_auth_token(client, "update_rule_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    create_resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "Initial Monthly Plan",
        "amount": 2000.00,
        "category": "Bills",
        "frequency": "monthly",
        "start_date": "2026-01-01"
    })
    rule_id = create_resp.json()["id"]

    # Valid update
    update_resp = client.put(f"/api/v1/recurring-expenses/{rule_id}", headers=headers, json={
        "title": "Upgraded Yearly Plan",
        "amount": 22000.00,
        "category": "Education",
        "frequency": "yearly",
        "end_date": "2028-12-31"
    })
    assert update_resp.status_code == 200
    updated = update_resp.json()
    assert updated["title"] == "Upgraded Yearly Plan"
    assert Decimal(str(updated["amount"])) == Decimal("22000.00")
    assert updated["category"] == "Education"
    assert updated["frequency"] == "yearly"
    assert updated["end_date"] == "2028-12-31"

    # Invalid end date earlier than start date
    bad_update = client.put(f"/api/v1/recurring-expenses/{rule_id}", headers=headers, json={
        "end_date": "2025-01-01"
    })
    assert bad_update.status_code == 422

