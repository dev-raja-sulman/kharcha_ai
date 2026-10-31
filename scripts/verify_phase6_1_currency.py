import os
import sys
import time
from decimal import Decimal
from datetime import date

# Add project root to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def run_verification():
    print("=" * 80)
    print("  KharchaAI -- Phase 6.1 Multi-Currency & Monthly Dashboard Live Verification")
    print("=" * 80)

    # 1. Supported Currencies Endpoint
    res = client.get("/api/v1/currencies")
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    cur_data = res.json()
    codes = [c["code"] for c in cur_data.get("currencies", [])]
    expected_codes = ["PKR", "USD", "EUR", "GBP", "AED", "SAR", "INR", "CAD", "AUD"]
    for code in expected_codes:
        assert code in codes, f"Expected currency {code} in supported currencies"
    print(f"[PASS] 1. Supported currencies: {codes} (Base: {cur_data.get('base_currency')})")

    # 2. Register new user and verify default preferred currency is PKR
    test_email = f"phase61_verify_{int(time.time() * 1000)}@kharcha.ai"
    reg_res = client.post("/api/v1/auth/register", json={
        "email": test_email,
        "password": "StrongPassword123!",
        "full_name": "Multi Currency Verifier"
    })
    assert reg_res.status_code == 201, f"Registration failed: {reg_res.text}"
    token = reg_res.json()["access_token"]
    user_info = reg_res.json()["user"]
    assert user_info.get("preferred_currency") == "PKR", f"Default currency should be PKR, got {user_info.get('preferred_currency')}"
    print(f"[PASS] 2. Default preferred currency for new user is PKR ({user_info.get('preferred_currency')})")

    headers = {"Authorization": f"Bearer {token}"}

    # 3. Currency Update: User switches preferred currency to USD and back to PKR
    upd_res = client.patch("/api/v1/auth/me", headers=headers, json={"preferred_currency": "USD"})
    assert upd_res.status_code == 200
    assert upd_res.json()["preferred_currency"] == "USD"

    upd_res2 = client.put("/api/v1/auth/currency", headers=headers, json={"preferred_currency": "PKR"})
    assert upd_res2.status_code == 200
    assert upd_res2.json()["preferred_currency"] == "PKR"
    print("[PASS] 3. Successfully updated user preferred currency via PATCH and PUT")

    # 4. October 2026 Deficit Scenario
    # Income: PKR 50,000
    inc_res = client.post("/api/v1/incomes", headers=headers, json={
        "title": "October Salary",
        "amount": "50000.00",
        "currency": "PKR",
        "income_date": "2026-10-01",
        "payment_method": "Bank Transfer",
        "description": "Monthly earnings"
    })
    assert inc_res.status_code == 201, f"Failed to create income: {inc_res.text}"

    # Expenses: PKR 92,020 total (e.g. Rent: 60,000 + Groceries: 32,020)
    exp1 = client.post("/api/v1/expenses", headers=headers, json={
        "title": "Apartment Rent",
        "amount": "60000.00",
        "currency": "PKR",
        "category": "Rent",
        "expense_date": "2026-10-05",
        "payment_method": "Bank Transfer"
    })
    assert exp1.status_code == 201

    exp2 = client.post("/api/v1/expenses", headers=headers, json={
        "title": "Monthly Groceries",
        "amount": "32020.00",
        "currency": "PKR",
        "category": "Groceries",
        "expense_date": "2026-10-10",
        "payment_method": "Card"
    })
    assert exp2.status_code == 201

    # Verify Cashflow for October 2026
    cf_res = client.get("/api/v1/analytics/cashflow?month=10&year=2026", headers=headers)
    assert cf_res.status_code == 200, f"Cashflow error: {cf_res.text}"
    cf_data = cf_res.json()

    assert Decimal(str(cf_data["total_income"])) == Decimal("50000.00")
    assert Decimal(str(cf_data["total_expenses"])) == Decimal("92020.00")
    assert Decimal(str(cf_data["net_cashflow"])) == Decimal("-42020.00")
    assert cf_data["currency"] == "PKR"
    assert "Your expenses exceed your income by PKR 42,020 this month." in cf_data["health_summary"]

    print(f"[PASS] 4. October 2026 Deficit Scenario Verified:")
    print(f"   - Income: PKR {float(cf_data["total_income"]):,.2f}")
    print(f"   - Expenses: PKR {float(cf_data["total_expenses"]):,.2f}")
    print(f"   - Net Cashflow: PKR {float(cf_data["net_cashflow"]):,.2f}")
    print(f"   - Health Summary: \"{cf_data['health_summary']}\"")

    # 5. Month Isolation: November 2026 must be isolated
    cf_nov = client.get("/api/v1/analytics/cashflow?month=11&year=2026", headers=headers)
    assert cf_nov.status_code == 200
    assert Decimal(str(cf_nov.json()["total_income"])) == Decimal("0.00")
    assert Decimal(str(cf_nov.json()["total_expenses"])) == Decimal("0.00")
    print("[PASS] 5. Month isolation verified (November 2026 has 0 bleed from October 2026)")

    # 6. Multi-Currency integrity & conversion without inventing rates
    # Add a USD 10 expense on 2026-10-15
    exp_usd = client.post("/api/v1/expenses", headers=headers, json={
        "title": "Cloud Server Hosting",
        "amount": "10.00",
        "currency": "USD",
        "category": "Software",
        "expense_date": "2026-10-15",
        "payment_method": "Credit Card"
    })
    assert exp_usd.status_code == 201
    created_usd_id = exp_usd.json()["id"]

    # Verify expense in DB retains USD and 10.00
    get_usd = client.get(f"/api/v1/expenses/{created_usd_id}", headers=headers)
    assert get_usd.status_code == 200
    assert get_usd.json()["currency"] == "USD"
    assert Decimal(str(get_usd.json()["amount"])) == Decimal("10.00")
    print(f"[PASS] 6. Original transaction currency and amount preserved in database (USD 10.00)")

    # 7. Summary with Currency Conversion and by_currency breakdown
    # Exchange rate USD -> PKR is 278.50. 10 USD = 2,785 PKR.
    # Total PKR expenses: 92,020 + 2,785 = 94,805 PKR.
    summary_res = client.get("/api/v1/expenses/summary?start_date=2026-10-01&end_date=2026-10-31&currency=PKR", headers=headers)
    assert summary_res.status_code == 200
    summary_data = summary_res.json()
    assert Decimal(str(summary_data["total_amount"])) == Decimal("94805.00")
    assert Decimal(str(summary_data["by_currency"]["USD"])) == Decimal("10.00")
    assert Decimal(str(summary_data["by_currency"]["PKR"])) == Decimal("92020.00")
    print(f"[PASS] 7. Converted summary in PKR: PKR {Decimal(str(summary_data['total_amount'])):,.2f}")
    print(f"   - Raw currency breakdown preserved: {summary_data['by_currency']}")

    print("=" * 80)
    print("  ALL PHASE 6.1 MULTI-CURRENCY & DASHBOARD VERIFICATIONS PASSED SUCCESSFULLY!")
    print("=" * 80)

if __name__ == "__main__":
    run_verification()
