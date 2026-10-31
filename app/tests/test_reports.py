from datetime import date, timedelta
from decimal import Decimal
import pytest


def get_auth_token(client, email="reports_user@test.com", password="SecurePassword123!"):
    resp = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": password,
        "full_name": "Reports Tester"
    })
    if resp.status_code == 201:
        return resp.json()["access_token"]
    login_resp = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    return login_resp.json()["access_token"]


def test_empty_report_handling(client):
    token = get_auth_token(client, "empty_report@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    resp = client.get("/api/v1/reports?report_type=monthly&year=2026&month=1", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert Decimal(str(data["total_expenditure"])) == Decimal("0.00")
    assert data["total_expenses"] == 0
    assert Decimal(str(data["average_daily_spending"])) == Decimal("0.00")
    assert data["highest_spending_category"] is None
    assert data["category_breakdown"] == []
    assert Decimal(str(data["recurring_vs_regular"]["recurring_amount"])) == Decimal("0.00")
    assert Decimal(str(data["recurring_vs_regular"]["regular_amount"])) == Decimal("0.00")
    assert Decimal(str(data["period_comparison"]["difference"])) == Decimal("0.00")


def test_advanced_report_metrics_and_trends(client):
    token = get_auth_token(client, "metrics_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    # Add regular expenses
    today = date(2026, 5, 15)
    client.post("/api/v1/expenses", headers=headers, json={
        "title": "Grocery Run",
        "amount": 3000.00,
        "category": "Food",
        "expense_date": "2026-05-10"
    })
    client.post("/api/v1/expenses", headers=headers, json={
        "title": "Bus Fare",
        "amount": 500.00,
        "category": "Transport",
        "expense_date": "2026-05-12"
    })

    # Add recurring rule and process it
    rule_resp = client.post("/api/v1/recurring-expenses", headers=headers, json={
        "title": "Internet Fiber",
        "amount": 2500.00,
        "category": "Bills",
        "frequency": "monthly",
        "start_date": "2026-05-01"
    })
    rule_id = rule_resp.json()["id"]

    # Process recurring expense
    proc = client.post("/api/v1/recurring-expenses/process", headers=headers)
    assert proc.json()["generated_count"] >= 1

    # Fetch Monthly Report for May 2026
    resp = client.get("/api/v1/reports?report_type=monthly&year=2026&month=5", headers=headers)
    assert resp.status_code == 200
    data = resp.json()

    # Total = 3000 + 500 + 2500 = 6000
    assert Decimal(str(data["total_expenditure"])) == Decimal("6000.00")
    assert data["total_expenses"] == 3

    # Check category breakdown
    assert len(data["category_breakdown"]) == 3
    assert data["highest_spending_category"]["category"] == "Food"
    assert Decimal(str(data["highest_spending_category"]["total_amount"])) == Decimal("3000.00")

    # Check recurring vs regular
    rec_reg = data["recurring_vs_regular"]
    assert Decimal(str(rec_reg["recurring_amount"])) == Decimal("2500.00")
    assert rec_reg["recurring_count"] == 1
    assert Decimal(str(rec_reg["regular_amount"])) == Decimal("3500.00")
    assert rec_reg["regular_count"] == 2

    # Check trends exist
    assert len(data["spending_trends"]) > 0


def test_period_comparison_variance(client):
    token = get_auth_token(client, "mom_comp@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    # Month 1: April 2026 (PKR 4000)
    client.post("/api/v1/expenses", headers=headers, json={
        "title": "April Shopping",
        "amount": 4000.00,
        "category": "Shopping",
        "expense_date": "2026-04-10"
    })

    # Month 2: May 2026 (PKR 6000)
    client.post("/api/v1/expenses", headers=headers, json={
        "title": "May Shopping",
        "amount": 6000.00,
        "category": "Shopping",
        "expense_date": "2026-05-10"
    })

    resp = client.get("/api/v1/reports?report_type=monthly&year=2026&month=5", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    comp = data["period_comparison"]
    assert comp is not None
    assert Decimal(str(comp["previous_expenditure"])) == Decimal("4000.00")
    assert Decimal(str(comp["difference"])) == Decimal("2000.00")
    assert comp["percentage_change"] == 50.0
    assert comp["trend"] == "increased"


def test_csv_export_and_injection_prevention(client):
    token = get_auth_token(client, "csv_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    # Create an expense with potential formula injection title
    malicious_title = "=cmd|'/C calc'!A0"
    client.post("/api/v1/expenses", headers=headers, json={
        "title": malicious_title,
        "amount": 1250.00,
        "category": "Other",
        "expense_date": "2026-08-15"
    })

    # Export CSV
    resp = client.get("/api/v1/reports/export/csv?report_type=monthly&year=2026&month=8", headers=headers)
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/csv")
    content = resp.content.decode("utf-8-sig")

    # Verify header summary
    assert "KharchaAI Financial Report" in content
    assert "Total Expenditure (PKR)" in content

    # Verify formula injection is escaped with a prepended single quote
    assert "'=cmd|'/C calc'!A0" in content


def test_pdf_export_generation(client):
    token = get_auth_token(client, "pdf_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    client.post("/api/v1/expenses", headers=headers, json={
        "title": "Medical Checkup",
        "amount": 4500.00,
        "category": "Healthcare",
        "expense_date": "2026-09-10"
    })

    resp = client.get("/api/v1/reports/export/pdf?report_type=monthly&year=2026&month=9", headers=headers)
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "application/pdf"
    assert "attachment; filename=" in resp.headers["content-disposition"]
    # Verify PDF file signature %PDF-
    assert resp.content.startswith(b"%PDF-")
    assert len(resp.content) > 1000  # Valid substantial PDF file


def test_reports_cross_user_isolation(client):
    token_1 = get_auth_token(client, "user_rep1@test.com")
    token_2 = get_auth_token(client, "user_rep2@test.com")

    # User 1 logs 10,000 PKR expense
    client.post(
        "/api/v1/expenses",
        headers={"Authorization": f"Bearer {token_1}"},
        json={
            "title": "Secret Expense",
            "amount": 10000.00,
            "category": "Shopping",
            "expense_date": "2026-07-01"
        }
    )

    # User 2 generates report for same period
    resp2 = client.get(
        "/api/v1/reports?report_type=monthly&year=2026&month=7",
        headers={"Authorization": f"Bearer {token_2}"}
    )
    assert resp2.status_code == 200
    assert Decimal(str(resp2.json()["total_expenditure"])) == Decimal("0.00")
    assert resp2.json()["total_expenses"] == 0


def test_invalid_date_range_rejected_422(client):
    token = get_auth_token(client, "invalid_range_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    # Custom report with end_date earlier than start_date
    resp = client.get(
        "/api/v1/reports?report_type=custom&start_date=2026-06-30&end_date=2026-06-01",
        headers=headers
    )
    assert resp.status_code == 422
    assert "cannot be earlier than start date" in resp.json()["detail"].lower()


def test_category_filtered_report(client):
    token = get_auth_token(client, "cat_filter_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    # Add Food expense (2,500) and Transport expense (1,200)
    client.post("/api/v1/expenses", headers=headers, json={
        "title": "Dinner Restaurant",
        "amount": 2500.00,
        "category": "Food",
        "expense_date": "2026-08-10"
    })
    client.post("/api/v1/expenses", headers=headers, json={
        "title": "Taxi Ride",
        "amount": 1200.00,
        "category": "Transport",
        "expense_date": "2026-08-11"
    })

    # Fetch report filtered strictly by category=Food
    resp = client.get(
        "/api/v1/reports?report_type=monthly&year=2026&month=8&category=Food",
        headers=headers
    )
    assert resp.status_code == 200
    data = resp.json()
    assert Decimal(str(data["total_expenditure"])) == Decimal("2500.00")
    assert data["total_expenses"] == 1
    assert len(data["category_breakdown"]) == 1
    assert data["category_breakdown"][0]["category"] == "Food"
    assert Decimal(str(data["category_breakdown"][0]["total_amount"])) == Decimal("2500.00")


def test_daily_weekly_yearly_report_types(client):
    token = get_auth_token(client, "periods_user@test.com")
    headers = {"Authorization": f"Bearer {token}"}

    # Add expense
    client.post("/api/v1/expenses", headers=headers, json={
        "title": "Annual Insurance",
        "amount": 15000.00,
        "category": "Bills",
        "expense_date": "2026-03-15"
    })

    # 1. Daily Report
    resp_daily = client.get(
        "/api/v1/reports?report_type=daily&start_date=2026-03-15",
        headers=headers
    )
    assert resp_daily.status_code == 200
    assert resp_daily.json()["report_type"] == "daily"
    assert Decimal(str(resp_daily.json()["total_expenditure"])) == Decimal("15000.00")

    # 2. Weekly Report
    resp_weekly = client.get(
        "/api/v1/reports?report_type=weekly&start_date=2026-03-09&end_date=2026-03-15",
        headers=headers
    )
    assert resp_weekly.status_code == 200
    assert resp_weekly.json()["report_type"] == "weekly"
    assert Decimal(str(resp_weekly.json()["total_expenditure"])) == Decimal("15000.00")

    # 3. Yearly Report
    resp_yearly = client.get(
        "/api/v1/reports?report_type=yearly&year=2026",
        headers=headers
    )
    assert resp_yearly.status_code == 200
    assert resp_yearly.json()["report_type"] == "yearly"
    assert Decimal(str(resp_yearly.json()["total_expenditure"])) == Decimal("15000.00")

