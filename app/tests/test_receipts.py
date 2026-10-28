from datetime import date
from decimal import Decimal
import io
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.core.config import settings
from app.schemas.expense import ExpenseCategory
from app.services.categorizer import SmartCategorizer
from app.services.receipt_providers.mock_provider import MockReceiptProvider
from app.services.receipt_providers.rule_based_provider import RuleBasedReceiptProvider
from app.services.receipt_service import ReceiptService


def _get_auth_header(client: TestClient, email: str = "receipt_user@kharcha.ai") -> dict:
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "Password123!",
        "full_name": "Receipt Tester"
    })
    res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "Password123!"
    })
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _create_sample_jpeg_bytes(width: int = 200, height: int = 300) -> bytes:
    img = Image.new("RGB", (width, height), color=(245, 245, 245))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------

def test_unauthenticated_receipt_scan_rejected(client: TestClient):
    """Requirement 1: Unauthenticated requests to /api/v1/receipts/scan must be rejected with 401."""
    jpeg_bytes = _create_sample_jpeg_bytes()
    response = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("receipt.jpg", jpeg_bytes, "image/jpeg")}
    )
    assert response.status_code == 401
    assert "token is missing" in response.json()["detail"].lower()


def test_invalid_file_type_rejected(client: TestClient):
    """Requirement 2: Non-image file types (e.g. text/pdf) must be rejected with 400."""
    headers = _get_auth_header(client, "bad_type@kharcha.ai")
    response = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("notes.txt", b"Total amount is 500", "text/plain")},
        headers=headers
    )
    assert response.status_code == 400
    assert "unsupported image format" in response.json()["detail"].lower()


def test_corrupted_image_rejected(client: TestClient):
    """Requirement 4: Files with fake image mime types but corrupted binaries must return 400."""
    headers = _get_auth_header(client, "corrupt@kharcha.ai")
    fake_jpeg = b"\xff\xd8\xffCORRUPTED_NON_IMAGE_DATA_0000"
    response = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("corrupt.jpg", fake_jpeg, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 400
    assert "corrupted" in response.json()["detail"].lower() or "signature" in response.json()["detail"].lower()


def test_oversized_file_rejected(client: TestClient, monkeypatch):
    """Requirement 3: Files exceeding the maximum allowed size must be rejected with 413."""
    headers = _get_auth_header(client, "oversized@kharcha.ai")
    # Temporarily set max size to 500 bytes for deterministic test
    monkeypatch.setattr(settings, "RECEIPT_MAX_UPLOAD_BYTES", 500)
    jpeg_bytes = _create_sample_jpeg_bytes()  # typically ~1000 bytes
    assert len(jpeg_bytes) > 500

    response = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("huge_receipt.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 413
    assert "exceeds maximum" in response.json()["detail"].lower()


def test_valid_scan_returns_structured_response(client: TestClient, monkeypatch):
    """Requirement 6: Valid extraction follows expected schema."""
    headers = _get_auth_header(client, "valid_scan@kharcha.ai")
    mock_provider = MockReceiptProvider(
        merchant_name="Imtiaz Super Market",
        amount=Decimal("3450.00"),
        suggested_category=ExpenseCategory.FOOD,
        category_explanation="Supermarket food groceries",
        confidence=0.92
    )
    monkeypatch.setattr(ReceiptService, "get_default_provider", lambda: mock_provider)

    jpeg_bytes = _create_sample_jpeg_bytes()
    response = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("imtiaz_receipt.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 200
    data = response.json()
    assert data["merchant_name"] == "Imtiaz Super Market"
    assert data["amount"] == "3450.00"
    assert data["suggested_category"] == "Food"
    assert data["currency"] == "PKR"
    assert data["confidence"] == 0.92
    assert len(data["line_items"]) == 2
    assert data["provider_used"] == "mock"


def test_suggested_categories_match_existing_categories():
    """Requirement 7: Suggested categories must always be valid ExpenseCategory members."""
    # Test food keywords
    cat_food, _ = SmartCategorizer.suggest_category(merchant_name="KFC Gulberg")
    assert cat_food == ExpenseCategory.FOOD
    assert cat_food.value in ExpenseCategory.list_all()

    # Test transport keywords
    cat_trans, _ = SmartCategorizer.suggest_category(merchant_name="Shell Fuel Station")
    assert cat_trans == ExpenseCategory.TRANSPORT

    # Test healthcare keywords
    cat_health, _ = SmartCategorizer.suggest_category(merchant_name="Chughtai Lab Pharmacy")
    assert cat_health == ExpenseCategory.HEALTHCARE

    # Test bills keywords
    cat_bills, _ = SmartCategorizer.suggest_category(merchant_name="LESCO Electricity Bill")
    assert cat_bills == ExpenseCategory.BILLS

    # Test unknown merchant defaults to Other
    cat_other, _ = SmartCategorizer.suggest_category(merchant_name="X9Z Unknown Corp")
    assert cat_other == ExpenseCategory.OTHER


def test_receipt_scan_does_not_create_expense_automatically(client: TestClient, monkeypatch):
    """Requirement 9 & 10: Receipt scan preview must NOT persist an expense to the database."""
    headers = _get_auth_header(client, "no_auto_save@kharcha.ai")
    mock_provider = MockReceiptProvider(amount=Decimal("1200.00"))
    monkeypatch.setattr(ReceiptService, "get_default_provider", lambda: mock_provider)

    # Verify initial expense list is empty
    initial_res = client.get("/api/v1/expenses", headers=headers)
    assert initial_res.status_code == 200
    assert initial_res.json()["total"] == 0

    # Scan receipt
    jpeg_bytes = _create_sample_jpeg_bytes()
    scan_res = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("receipt.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert scan_res.status_code == 200

    # Verify expense list is STILL 0 (not auto-created)
    after_res = client.get("/api/v1/expenses", headers=headers)
    assert after_res.status_code == 200
    assert after_res.json()["total"] == 0


def test_confirm_receipt_creates_exactly_one_expense(client: TestClient, monkeypatch):
    """Requirement 8 & 9: Confirming extracted/edited fields creates exactly 1 expense via existing API."""
    headers = _get_auth_header(client, "confirm_save@kharcha.ai")
    mock_provider = MockReceiptProvider(
        merchant_name="Total Parco Fuel Station",
        amount=Decimal("5000.00"),
        suggested_category=ExpenseCategory.TRANSPORT
    )
    monkeypatch.setattr(ReceiptService, "get_default_provider", lambda: mock_provider)

    # 1. Scan receipt
    jpeg_bytes = _create_sample_jpeg_bytes()
    scan_res = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("fuel_receipt.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert scan_res.status_code == 200
    extracted = scan_res.json()

    # 2. Simulate user editing the amount from 5000.00 to 5200.00 and confirming
    expense_payload = {
        "title": extracted["merchant_name"],
        "amount": "5200.00",  # user edited
        "category": extracted["suggested_category"],
        "description": f"AI Receipt scan: {extracted['category_explanation']}",
        "expense_date": extracted["transaction_date"] or str(date.today()),
        "payment_method": "Card"
    }

    # 3. User taps 'Confirm & Save' -> posts to existing /api/v1/expenses
    save_res = client.post("/api/v1/expenses", json=expense_payload, headers=headers)
    assert save_res.status_code == 201
    created_expense = save_res.json()
    assert created_expense["title"] == "Total Parco Fuel Station"
    assert created_expense["amount"] == "5200.00"
    assert created_expense["category"] == "Transport"

    # 4. Verify exactly 1 expense exists
    list_res = client.get("/api/v1/expenses", headers=headers)
    assert list_res.status_code == 200
    assert list_res.json()["total"] == 1


def test_provider_failure_returns_clear_error(client: TestClient, monkeypatch):
    """Requirement 5: Upstream provider failure returns clear error without crashing."""
    headers = _get_auth_header(client, "fail_prov@kharcha.ai")
    mock_provider = MockReceiptProvider(should_fail=True, failure_message="Upstream AI provider timeout")
    monkeypatch.setattr(ReceiptService, "get_default_provider", lambda: mock_provider)

    jpeg_bytes = _create_sample_jpeg_bytes()
    response = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("receipt.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 502
    assert "upstream ai provider timeout" in response.json()["detail"].lower()


def test_unconfigured_provider_error(client: TestClient, monkeypatch):
    """Requirement 5: If Gemini is selected but GEMINI_API_KEY is empty, returns 503."""
    headers = _get_auth_header(client, "unconf@kharcha.ai")
    monkeypatch.setattr(settings, "RECEIPT_AI_PROVIDER", "gemini")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "")

    jpeg_bytes = _create_sample_jpeg_bytes()
    response = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("receipt.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 503
    assert "gemini api key is not configured" in response.json()["detail"].lower()


def test_rule_based_provider_execution(client: TestClient, monkeypatch):
    """Verifies that the RuleBasedReceiptProvider runs locally and returns clear warnings."""
    headers = _get_auth_header(client, "rule_based@kharcha.ai")
    monkeypatch.setattr(settings, "RECEIPT_AI_PROVIDER", "rule_based")

    jpeg_bytes = _create_sample_jpeg_bytes(width=250, height=400)
    response = client.post(
        "/api/v1/receipts/scan",
        files={"file": ("pso_fuel_2500.jpg", jpeg_bytes, "image/jpeg")},
        headers=headers
    )
    assert response.status_code == 200
    data = response.json()
    assert data["provider_used"] == "rule_based"
    assert data["suggested_category"] == "Transport"
    assert data["amount"] == "2500.00"
    assert any("rule-based" in w.lower() for w in data["warnings"])
