# KharchaAI — Phase 1, Phase 2 & Phase 3: AI Expense Management

KharchaAI is an AI-powered personal expense tracker and financial management app. This repository contains:
- **Phase 1**: Authentication, JWT Security, & Flutter-FastAPI integration
- **Phase 2**: Expense Management CRUD, Alembic migrations, Multi-User Isolation, and Dashboard Summaries
- **Phase 3**: AI Receipt Scanning (Google Gemini Vision & Local OCR), Smart Expense Categorization, and Review & Confirm Workflow

---

## 📁 Project Architecture

```
Karcha AI App/
├── alembic/                             # Alembic Database Migrations (PostgreSQL/SQLite)
│   ├── env.py                           # Dynamic migration runner connected to Base.metadata
│   └── versions/                        # Versioned migration revision scripts
├── app/                                 # FastAPI Backend (Modular Architecture)
│   ├── api/
│   │   ├── deps.py                      # JWT Bearer token dependency (get_current_user)
│   │   ├── api.py                       # v1 router registry (Auth + Expenses + Receipts)
│   │   └── routes/
│   │       ├── auth.py                  # Endpoints: /register, /login, /me
│   │       ├── expenses.py              # Endpoints: /expenses, /expenses/summary, /expenses/{id}
│   │       └── receipts.py              # Endpoint: POST /receipts/scan
│   ├── core/
│   │   ├── config.py                    # Settings & environment variables (pydantic-settings)
│   │   └── security.py                  # Direct bcrypt hashing & JWT encoding/decoding
│   ├── db/
│   │   ├── base.py                      # SQLAlchemy declarative base
│   │   └── session.py                   # Engine, SessionLocal, init_db, get_db generator
│   ├── models/
│   │   ├── user.py                      # User model (id, email, hashed_password, full_name, is_active)
│   │   └── expense.py                   # Expense model (Numeric(12,2), category index, check constraints)
│   ├── schemas/
│   │   ├── auth.py                      # Auth request/response schemas
│   │   ├── expense.py                   # Expense schemas, Enum categories, summaries
│   │   └── receipt.py                   # Receipt scan request/response schemas & line items
│   ├── services/
│   │   ├── auth_service.py              # Business logic: registration, authentication, profile lookups
│   │   ├── expense_service.py           # Multi-tenant expense CRUD, aggregations & data isolation
│   │   ├── categorizer.py               # Deterministic smart categorizer mapping terms to ExpenseCategory
│   │   ├── receipt_service.py           # Upload validation, size/mime limits, provider orchestration
│   │   └── receipt_providers/           # Provider abstraction layer
│   │       ├── base.py                  # BaseReceiptProvider abstract interface
│   │       ├── gemini_provider.py       # Google Gemini Vision integration via httpx
│   │       ├── rule_based_provider.py   # Local Pillow raster validation & deterministic heuristics
│   │       └── mock_provider.py         # Mock provider for automated test suite
│   ├── static/
│   │   └── web_app.html                 # Interactive visual web testing console with receipt scanning
│   ├── tests/                           # Pytest automated test suite (28 passed)
│   │   ├── conftest.py                  # In-memory test SQLite session & client fixture
│   │   ├── test_health.py               # Health endpoint test
│   │   ├── test_auth.py                 # 9 security & auth tests
│   │   ├── test_expenses.py             # 7 expense CRUD, validation & multi-user isolation tests
│   │   └── test_receipts.py             # 11 receipt scanning, validation & confirmation tests
│   └── main.py                          # FastAPI application factory, CORS & /health
├── lib/                                 # KharchaAI Flutter Frontend
│   ├── core/
│   │   ├── config/
│   │   │   └── api_config.dart          # Environment/platform host selector (10.0.2.2, physical IP, production)
│   │   ├── constants/
│   │   │   └── app_colors.dart          # Palette: Deep Emerald (#0F766E), Mint (#14B8A6), Slate
│   │   ├── network/
│   │   │   ├── api_client.dart          # Dio instance with timeouts & interceptors
│   │   │   ├── api_exception.dart       # User-friendly network failure translation
│   │   │   └── auth_interceptor.dart    # Auto-attaches Bearer token; handles 401 session expiry
│   │   └── storage/
│   │       └── secure_storage_service.dart # Platform secure storage for JWT token
│   ├── models/
│   │   ├── user_model.dart              # User profile data model & JSON serialization
│   │   ├── auth_response.dart           # Token response wrapper
│   │   ├── expense_model.dart           # Expense model with PKR currency and date formatting
│   │   ├── expense_summary.dart         # Category and payment method aggregations
│   │   └── receipt_scan_model.dart      # Receipt scan extraction data model & line items
│   ├── services/
│   │   ├── auth_service.dart            # Flutter authentication API consumer
│   │   ├── expense_service.dart         # Flutter expense CRUD API consumer
│   │   └── receipt_service.dart         # Flutter receipt scanning API consumer (Dio multipart)
│   ├── widgets/
│   │   ├── custom_button.dart           # Loading state & styled action button
│   │   ├── custom_text_field.dart       # Form field with validation & password visibility toggle
│   │   └── add_expense_sheet.dart       # Modal bottom sheet for adding & editing expenses
│   ├── screens/
│   │   ├── splash_screen.dart           # Auto-checks token & navigates to Dashboard or Login
│   │   ├── login_screen.dart            # Login form with validation & error banner
│   │   ├── register_screen.dart         # Sign-up form with password confirmation
│   │   ├── dashboard_screen.dart        # Real-time financial dashboard with live expenses & Scan button
│   │   ├── scan_receipt_screen.dart     # AI Receipt scanning, progress indicator, review & confirmation
│   │   └── profile_screen.dart          # User account details & logout dialog
│   └── main.dart                        # App bootstrap & theme setup
├── scripts/
│   └── verify_api_integration.py        # Automated end-to-end 24-point live integration check
├── test/                                # Flutter Unit Tests
│   ├── models_test.dart
│   ├── api_config_test.dart
│   ├── expense_models_test.dart
│   └── receipt_models_test.dart
├── .env.example                         # Template environment configuration
├── .env                                 # Active local development configuration
├── pubspec.yaml                         # Flutter dependencies manifest
├── requirements.txt                     # Python dependencies manifest
├── run_backend.bat                      # Windows one-click backend runner
└── run_flutter.bat                      # Windows one-click Flutter runner
```

---

## 🚀 Running the Backend (FastAPI) on Windows

### Option 1: One-Click Batch Script
Double-click `run_backend.bat` or run in terminal:
```powershell
.\run_backend.bat
```

### Option 2: PowerShell Command
```powershell
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

- **Interactive API Docs (Swagger UI):** [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Health Check Endpoint:** [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

---

## 📱 Running the Flutter Frontend

### Option 1: Android Emulator
The Android emulator automatically maps host computer `127.0.0.1` to `10.0.2.2`.
```powershell
flutter run
```

### Option 2: Windows Desktop or Chrome Web
```powershell
flutter run -d chrome
```

### Option 3: Physical Mobile Device (Wi-Fi)
Pass your computer's local Wi-Fi IP address:
```powershell
flutter run --dart-define=API_URL=http://192.168.1.13:8000
```

---

## 🌐 API Base URL Mapping

| Target Platform | Base URL | Why? |
| :--- | :--- | :--- |
| **Android Emulator** | `http://10.0.2.2:8000` | Android emulators run in a QEMU virtual network; `10.0.2.2` redirects to the host PC's loopback interface. |
| **iOS Simulator** | `http://127.0.0.1:8000` | iOS simulators share the host machine's network stack directly. |
| **Desktop / Web** | `http://127.0.0.1:8000` | Standard local loopback. |
| **Physical Phone (Wi-Fi)**| `http://192.168.1.13:8000`| The phone connects across the local Wi-Fi router to the PC's LAN IP address. |
| **Production** | `https://api.kharcha.ai` | TLS-encrypted cloud API. |

---

## 📸 Phase 3: AI Receipt Scanning & OCR Architecture

KharchaAI Phase 3 implements structured financial receipt scanning with a provider abstraction layer:
- **Google Gemini Vision (`gemini-1.5-flash`):** Multimodal cloud AI vision via lightweight `httpx` asynchronous calls. To enable, add your Gemini API key in `.env`:
  ```bash
  RECEIPT_AI_PROVIDER="gemini"
  GEMINI_API_KEY="your-google-ai-studio-api-key"
  ```
- **Local Rule-Based OCR Engine (`rule_based`):** Raster image binary and dimensional verification using Pillow with deterministic keyword category heuristics. Ideal for offline or unconfigured environments without paid cloud dependencies.
- **Review & Confirm Safety:** Receipt scanning (`POST /api/v1/receipts/scan`) **never** creates an expense automatically. It returns a structured preview with merchant name, amount, date, suggested category, confidence, and warnings. The user explicitly reviews and edits the fields, and confirms to call `POST /api/v1/expenses`.

---

## 🧪 Automated Test Results

### 1. Backend Pytest Suite (28 Passed)
Ran: `python -m pytest app/tests -v`
```
app/tests/test_auth.py (9 tests) ......................... PASSED
app/tests/test_expenses.py (7 tests) ..................... PASSED
app/tests/test_health.py (1 test) ........................ PASSED
app/tests/test_receipts.py (11 tests) .................... PASSED
======================= 28 passed in 15.73s =======================
```

### 2. Live End-to-End API Integration (24 Passed)
Ran: `python scripts/verify_api_integration.py`
```
[PASS] Step 1: Server Health Check (GET /health) -> 200 OK
[PASS] Step 2: Registration Input Validation -> 422 Unprocessable Entity
[PASS] Step 3: User Registration (POST /api/v1/auth/register) -> 201 Created
[PASS] Step 4: Duplicate Email Rejection -> 400 Bad Request
[PASS] Step 5: User Login (POST /api/v1/auth/login) -> 200 OK
[PASS] Step 6: Invalid Credentials Rejection -> 401 Unauthorized
[PASS] Step 7: Authenticated Profile Retrieval (GET /api/v1/auth/me) -> 200 OK
[PASS] Step 8: Unauthorized Access Protection -> 401 Unauthorized
[PASS] Step 9: Database Security Audit -> Bcrypt Hash Verified (Zero plaintext)
[PASS] Step 10: Network Failure Resilience Check -> Connection refusal mapped to friendly message
[PASS] Step 11: Expense Creation (POST /api/v1/expenses) -> 201 Created
[PASS] Step 12: Expense Amount & Title Validation -> 422 Rejected
[PASS] Step 13: List & Filter Expenses (GET /api/v1/expenses) -> Filtered by category
[PASS] Step 14: Expense Summary Aggregations (GET /api/v1/expenses/summary) -> Total sum & % breakdown
[PASS] Step 15: Update Expense (PATCH /api/v1/expenses/{id}) -> Updated amount
[PASS] Step 16: Multi-User Data Isolation Enforcement -> User 2 receives 404 on User 1's expense
[PASS] Step 17: Delete Expense (DELETE /api/v1/expenses/{id}) -> Status 200 OK
[PASS] Step 18: Unauthenticated Receipt Scan Rejection (401) -> Protected endpoint verified
[PASS] Step 19: Invalid File Type Rejection (400) -> PDF rejected
[PASS] Step 20: Unconfigured AI Provider Error Reporting (503) -> Friendly actionable message
[PASS] Step 21: Authenticated Receipt Scan (POST /api/v1/receipts/scan?provider=rule_based) -> 200 OK
[PASS] Step 22: No Auto-Creation Verification -> Expense count unchanged
[PASS] Step 23: Confirm & Save Receipt Expense (POST /api/v1/expenses) -> 201 Created
[PASS] Step 24: Verified Exactly One Expense Saved -> Count incremented by exactly 1
```

---

## 🗄️ Database Note: Phase 1 vs Phase 2
- **Phase 1 (Development):** Uses SQLite (`sqlite:///./kharcha_dev.db`). This allows zero-friction local development without requiring external database services.
- **Phase 2 (Production):** The SQLAlchemy models and `DATABASE_URL` setting are designed to switch seamlessly to **PostgreSQL** by updating `.env` (e.g. `DATABASE_URL=postgresql+psycopg://user:pass@localhost:5432/kharcha_ai`).
