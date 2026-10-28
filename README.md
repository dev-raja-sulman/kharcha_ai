# KharchaAI — Phase 1, 2, 3, 4 & 5: Personal Finance, AI Scanning, Budgets & Recurring Reports

KharchaAI is an AI-powered personal expense tracker and financial management app. This repository contains:
- **Phase 1**: Authentication, JWT Security, & Flutter-FastAPI integration
- **Phase 2**: Expense Management CRUD, Alembic migrations, Multi-User Isolation, and Dashboard Summaries
- **Phase 3**: AI Receipt Scanning (Google Gemini Vision & Local OCR), Smart Expense Categorization, and Review & Confirm Workflow
- **Phase 4**: Smart Monthly Budgets, 50%/80%/100% Threshold Alerts, Spending Analytics, and AI Spending Insights
- **Phase 5**: Recurring Expenses Automation, Advanced Financial Reports, Publication-Ready PDF & CSV Export, and Custom Date Filtering

---

## 📁 Project Architecture

```
Karcha AI App/
├── alembic/                             # Alembic Database Migrations (PostgreSQL/SQLite)
│   ├── env.py                           # Dynamic migration runner connected to Base.metadata
│   └── versions/                        # Versioned migration revision scripts
│       ├── a866122f5ef2_create_users_and_expenses_tables.py
│       ├── 85e7b4469633_create_budgets_table.py
│       └── c48e192f6b15_create_recurring_expenses_table.py
├── app/                                 # FastAPI Backend (Modular Architecture)
│   ├── api/
│   │   ├── deps.py                      # JWT Bearer token dependency (get_current_user)
│   │   ├── api.py                       # v1 router registry (Auth + Expenses + Receipts + Budgets + Analytics + Recurring + Reports)
│   │   └── routes/
│   │       ├── auth.py                  # Endpoints: /register, /login, /me
│   │       ├── expenses.py              # Endpoints: /expenses, /expenses/summary, /expenses/{id}
│   │       ├── receipts.py              # Endpoint: POST /receipts/scan
│   │       ├── budgets.py               # Endpoints: /budgets, /budgets/progress, /budgets/{id}
│   │       ├── analytics.py             # Endpoints: /analytics/spending, /analytics/insights
│   │       ├── recurring.py             # Endpoints: /recurring-expenses (CRUD, pause, resume, cancel, history, process)
│   │       └── reports.py               # Endpoints: /reports, /reports/export/csv, /reports/export/pdf
│   ├── core/
│   │   ├── config.py                    # Settings & environment variables (pydantic-settings)
│   │   └── security.py                  # Direct bcrypt hashing & JWT encoding/decoding
│   ├── db/
│   │   ├── base.py                      # SQLAlchemy declarative base
│   │   └── session.py                   # Engine, SessionLocal, init_db, get_db generator
│   ├── models/
│   │   ├── user.py                      # User model (id, email, hashed_password, full_name, is_active)
│   │   ├── expense.py                   # Expense model (Numeric(12,2), recurring_rule_id, recurring_occurrence_date)
│   │   ├── budget.py                    # Budget model (amount > 0, month 1-12, year, start/end dates)
│   │   └── recurring_expense.py         # RecurringExpense model (frequencies, start/end date, next_date, status)
│   ├── schemas/
│   │   ├── auth.py                      # Auth request/response schemas
│   │   ├── expense.py                   # Expense schemas, Enum categories, summaries
│   │   ├── receipt.py                   # Receipt scan request/response schemas & line items
│   │   ├── budget.py                    # Budget schemas, progress and alert levels
│   │   ├── analytics.py                 # Analytics and AI Spending Insights schemas
│   │   ├── recurring.py                 # Recurring expense rules schemas & responses
│   │   └── reports.py                   # Advanced reports, categories, comparisons & trend schemas
│   ├── services/
│   │   ├── auth_service.py              # Business logic: registration, authentication, profile lookups
│   │   ├── expense_service.py           # Multi-tenant expense CRUD, aggregations & data isolation
│   │   ├── categorizer.py               # Deterministic smart categorizer mapping terms to ExpenseCategory
│   │   ├── receipt_service.py           # Upload validation, size/mime limits, provider orchestration
│   │   ├── receipt_providers/           # Provider abstraction layer (Gemini, Rule-Based, Mock)
│   │   ├── budget_service.py            # Budget CRUD, calculations, and 50%/80%/100% threshold alerts
│   │   ├── analytics_service.py         # Daily velocity, weekly blocks, category breakdowns, MoM comparisons
│   │   ├── insights_service.py          # Evidence-based observations with optional Gemini natural language synthesis
│   │   ├── recurring_service.py         # Recurring rule lifecycle, calendar-safe date arithmetic & idempotent engine
│   │   ├── reports_service.py           # Advanced financial aggregations, periods comparison & recurring vs regular
│   │   └── export_service.py            # UTF-8 BOM CSV generation with injection defense & ReportLab PDF layout
│   ├── static/
│   │   └── web_app.html                 # Interactive visual console (Receipt scan, Budgets, Analytics, Recurring, Reports & PDF/CSV)
│   ├── tests/                           # Pytest automated test suite (53 passed)
│   │   ├── conftest.py                  # In-memory test SQLite session & client fixture
│   │   ├── test_health.py               # Health endpoint test
│   │   ├── test_auth.py                 # 9 security & auth tests
│   │   ├── test_expenses.py             # 7 expense CRUD, validation & multi-user isolation tests
│   │   ├── test_receipts.py             # 11 receipt scanning, validation & confirmation tests
│   │   ├── test_budgets.py              # 7 budget CRUD, validation, calculation & alert tests
│   │   ├── test_analytics.py            # 4 spending analytics, MoM comparison & AI insights tests
│   │   ├── test_recurring.py            # 7 recurring rules, date calculations & idempotency tests
│   │   └── test_reports.py              # 6 advanced reports, CSV injection guard & PDF export tests
│   └── main.py                          # FastAPI application factory, CORS, startup scheduler & /health
├── lib/                                 # KharchaAI Flutter Frontend
│   ├── core/
│   │   ├── config/
│   │   │   └── api_config.dart          # Environment/platform host selector & Phase 5 endpoints
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
│   │   ├── receipt_scan_model.dart      # Receipt scan extraction data model & line items
│   │   ├── budget_model.dart            # Budget data model with progress and alert indicators
│   │   ├── analytics_model.dart         # Spending analytics & AI insight items
│   │   ├── recurring_expense_model.dart # Recurring rules model with status & frequency helpers
│   │   └── report_model.dart            # Advanced report model with period comparisons & breakdown
│   ├── services/
│   │   ├── auth_service.dart            # Flutter authentication API consumer
│   │   ├── expense_service.dart         # Flutter expense CRUD API consumer
│   │   ├── receipt_service.dart         # Flutter receipt scanning API consumer (Dio multipart)
│   │   ├── budget_service.dart          # Flutter budget management API consumer
│   │   ├── analytics_service.dart       # Flutter spending analytics & AI insights API consumer
│   │   ├── recurring_service.dart       # Flutter recurring expense API consumer
│   │   └── report_service.dart          # Flutter reports, CSV & PDF export API consumer
│   ├── widgets/
│   │   ├── custom_button.dart           # Loading state & styled action button
│   │   ├── custom_text_field.dart       # Form field with validation & password visibility toggle
│   │   └── add_expense_sheet.dart       # Modal bottom sheet for adding & editing expenses
│   ├── screens/
│   │   ├── splash_screen.dart           # Auto-checks token & navigates to Dashboard or Login
│   │   ├── login_screen.dart            # Login form with validation & error banner
│   │   ├── register_screen.dart         # Sign-up form with password confirmation
│   │   ├── dashboard_screen.dart        # Real-time financial dashboard with quick navigation bar
│   │   ├── scan_receipt_screen.dart     # AI Receipt scanning, progress indicator, review & confirmation
│   │   ├── budget_screen.dart           # Smart monthly budgets, progress bars & threshold alerts
│   │   ├── analytics_screen.dart        # Category breakdowns, daily velocity, MoM trend, AI observations
│   │   ├── recurring_expenses_screen.dart # Recurring rules manager, pause/resume, history, and processing
│   │   ├── reports_screen.dart          # Advanced reports, timeframes, trend cards, CSV/PDF export
│   │   └── profile_screen.dart          # User account details & logout dialog
│   └── main.dart                        # App bootstrap & theme setup
├── scripts/
│   └── verify_api_integration.py        # Automated end-to-end 40-point live integration check
├── test/                                # Flutter Unit Tests
│   ├── models_test.dart
│   ├── api_config_test.dart
│   ├── expense_models_test.dart
│   ├── receipt_models_test.dart
│   ├── phase4_models_test.dart
│   └── phase5_models_test.dart
├── .env.example                         # Template environment configuration
├── .env                                 # Active local development configuration
├── pubspec.yaml                         # Flutter dependencies manifest
├── requirements.txt                     # Python dependencies manifest (including ReportLab)
├── run_backend.bat                      # Windows one-click backend runner
└── run_flutter.bat                      # Windows one-click Flutter runner
```

---

## 🔄 Phase 5: Recurring Expenses & Advanced Reports

### 1. Recurring Expenses Engine
- **Frequencies Supported:** Daily (`daily`), Weekly (`weekly`), Monthly (`monthly`), Yearly (`yearly`).
- **Calendar-Safe Arithmetic:** Safely clamps month-end dates (e.g. Jan 31 -> Feb 28 in non-leap years) and handles leap-year rollovers without crashes.
- **Idempotency & Duplicate Prevention:**
  - Enforces database uniqueness on `(recurring_rule_id, recurring_occurrence_date)` via `uq_expenses_recurring_occurrence`.
  - Repeated runner executions or system restarts will never produce duplicate expenses.
  - Generates expenses only within `[start_date, end_date]`.
- **Automatic Execution:**
  - Automatically runs idempotent due-occurrence processing during backend startup in `lifespan`.
  - Manual API trigger available at `POST /api/v1/recurring-expenses/process`.
  - Full history of expenses generated by each rule is preserved and queryable at `/api/v1/recurring-expenses/{id}/history`.

### 2. Advanced Expense Reports
- **Supported Timeframes:** `daily`, `weekly`, `monthly`, `yearly`, `custom`, and `category`.
- **Key Metrics:**
  - Total expenditure and transaction count.
  - Daily spending average over the active timeframe.
  - Category breakdown with expenditure amounts, percentages, and count.
  - Recurring vs Regular spending comparison.
  - Period-over-period comparison against the equivalent previous period (e.g. current month vs previous month; custom $N$-day range vs preceding $N$ days).
- **Empty Dataset Resilience:** Zero-division safe, returns exact Decimal `0.00` amounts without inventing or projecting fake data.

### 3. CSV & PDF Export
- **CSV Export (`/api/v1/reports/export/csv`):**
  - UTF-8 with BOM (`utf-8-sig`) for native Unicode character rendering across Microsoft Excel and LibreOffice.
  - **Formula Injection Defense (CWE-1236):** Sanitizes user-supplied text fields starting with `=`, `+`, `-`, `@`, `\t`, `\r` by prepending a single quote `'`.
- **PDF Export (`/api/v1/reports/export/pdf`):**
  - Generated using ReportLab with the KharchaAI emerald palette (`#0F766E`, `#115E59`, `#F0FDFA`).
  - Includes KPI summary cards, Recurring vs One-Off comparison box, Period-over-Period comparison box, Category breakdown table, and detailed transaction records.
  - Dynamic two-pass page numbering ("Page X of Y") and confidentiality notices.

---

## 🔌 Phase 5 API Endpoints

### Recurring Expenses (`/api/v1/recurring-expenses`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/recurring-expenses` | Create a new recurring expense rule |
| `GET` | `/api/v1/recurring-expenses` | List user's recurring rules (optional `?status=` filter) |
| `GET` | `/api/v1/recurring-expenses/{id}` | Retrieve details for a specific recurring rule |
| `PUT` | `/api/v1/recurring-expenses/{id}` | Update title, amount, category, frequency, or end date |
| `POST` | `/api/v1/recurring-expenses/{id}/pause` | Pause an active recurring rule |
| `POST` | `/api/v1/recurring-expenses/{id}/resume` | Resume a paused recurring rule |
| `POST` | `/api/v1/recurring-expenses/{id}/cancel` | Cancel a recurring rule (preserves history) |
| `DELETE` | `/api/v1/recurring-expenses/{id}` | Cancel/delete a recurring rule |
| `GET` | `/api/v1/recurring-expenses/{id}/history` | Get all expenses generated by this rule |
| `POST` | `/api/v1/recurring-expenses/process` | Trigger idempotent processing for all due occurrences |

### Advanced Reports (`/api/v1/reports`)
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/reports` | Get JSON report (`report_type`, `start_date`, `end_date`, `category`) |
| `GET` | `/api/v1/reports/export/csv` | Download filtered spreadsheet report as CSV |
| `GET` | `/api/v1/reports/export/pdf` | Download formatted publication-ready PDF report |

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
- **Interactive Visual Testing Console:** [http://127.0.0.1:8000/](http://127.0.0.1:8000/)
- **Health Check Endpoint:** [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

---

## 🗄️ Database Migrations

Apply Alembic migrations to upgrade the schema:
```powershell
python -m alembic upgrade head
```

Verify migration status:
```powershell
python -m alembic current
```

---

## 🧪 Automated Test Results

### 1. Backend Pytest Suite (53 Passed)
Run backend tests:
```powershell
python -m pytest app/tests -v
```
```
app/tests/test_auth.py (9 tests) ......................... PASSED
app/tests/test_expenses.py (7 tests) ..................... PASSED
app/tests/test_health.py (2 tests) ....................... PASSED
app/tests/test_receipts.py (11 tests) .................... PASSED
app/tests/test_budgets.py (7 tests) ...................... PASSED
app/tests/test_analytics.py (4 tests) .................... PASSED
app/tests/test_recurring.py (7 tests) .................... PASSED
app/tests/test_reports.py (6 tests) ...................... PASSED
======================= 53 passed in 44.12s =======================
```

### 2. Live End-to-End API Integration (40 Passed)
Run live verification script against running server:
```powershell
python scripts/verify_api_integration.py
```
```
[PASS] Step 1: Server Health Check (GET /health & GET /api/v1/health)
[PASS] Step 2: Registration Input Validation -> 422 Unprocessable Entity
[PASS] Step 3: User Registration (POST /api/v1/auth/register) -> 201 Created
[PASS] Step 4: Duplicate Email Rejection -> 400 Bad Request
[PASS] Step 5: User Login (POST /api/v1/auth/login) -> 200 OK
[PASS] Step 6: Invalid Credentials Rejection -> 401 Unauthorized
[PASS] Step 7: Authenticated Profile Retrieval (GET /api/v1/auth/me) -> 200 OK
[PASS] Step 8: Unauthorized Access Protection -> 401 Unauthorized
[PASS] Step 9: Database Security Audit -> Bcrypt Hash Verified
[PASS] Step 10: Network Failure Resilience Check -> Handled gracefully
[PASS] Step 11: Expense Creation (POST /api/v1/expenses) -> 201 Created
[PASS] Step 12: Expense Amount & Title Validation -> 422 Rejected
[PASS] Step 13: List & Filter Expenses (GET /api/v1/expenses) -> Filtered by category
[PASS] Step 14: Expense Summary Aggregations (GET /api/v1/expenses/summary) -> Total sum & % breakdown
[PASS] Step 15: Update Expense (PATCH /api/v1/expenses/{id}) -> Updated amount
[PASS] Step 16: Multi-User Data Isolation Enforcement -> User 2 receives 404
[PASS] Step 17: Delete Expense (DELETE /api/v1/expenses/{id}) -> Status 200 OK
[PASS] Step 18: Unauthenticated Receipt Scan Rejection (401)
[PASS] Step 19: Invalid File Type Rejection (400)
[PASS] Step 20: Unconfigured AI Provider Error Reporting (503)
[PASS] Step 21: Authenticated Receipt Scan (POST /api/v1/receipts/scan?provider=rule_based) -> 200 OK
[PASS] Step 22: No Auto-Creation Verification -> Expense count unchanged
[PASS] Step 23: Confirm & Save Receipt Expense (POST /api/v1/expenses) -> 201 Created
[PASS] Step 24: Verified Exactly One Expense Saved -> Count incremented by exactly 1
[PASS] Step 25: Unauthenticated Budget Access Rejection (401)
[PASS] Step 26: Create Overall Monthly Budget (POST /api/v1/budgets) -> 201 Created
[PASS] Step 27: Create Category Budget with Live Calculations (POST /api/v1/budgets) -> Warning 80% (92.5%)
[PASS] Step 28: Duplicate Budget Overlap Prevention (400) -> Overlapping duplicate rejected
[PASS] Step 29: Budget Progress & Active Alerts (GET /api/v1/budgets/progress) -> Live thresholds verified
[PASS] Step 30: Spending Analytics Aggregation (GET /api/v1/analytics/spending) -> Velocity & breakdown verified
[PASS] Step 31: AI Financial Spending Insights (GET /api/v1/analytics/insights) -> Evidence-based observations
[PASS] Step 32: Budget Multi-User Isolation & Deletion Enforcement -> User 2 404 verified, User 1 delete OK
[PASS] Step 33: Create Recurring Expense Rule (POST /api/v1/recurring-expenses) -> 201 Created
[PASS] Step 34: Process Due Recurring Expenses (POST /api/v1/recurring-expenses/process) -> Generated due expenses
[PASS] Step 35: Verify Idempotency on Repeated Processing -> 0 duplicates created
[PASS] Step 36: Pause and Resume Recurring Rule Lifecycle -> Successfully paused and resumed
[PASS] Step 37: Generate Advanced Financial Report (GET /api/v1/reports) -> Verified metrics & comparisons
[PASS] Step 38: Export Filtered CSV Report (GET /api/v1/reports/export/csv) -> UTF-8 BOM & injection guarded
[PASS] Step 39: Export Filtered PDF Report (GET /api/v1/reports/export/pdf) -> Valid %PDF- binary generated
[PASS] Step 40: Phase 5 Multi-User Tenant Isolation Enforcement -> Complete data isolation confirmed
===========================================================================
 ALL 40 PHASE 1, PHASE 2, PHASE 3, PHASE 4 & PHASE 5 CHECKS PASSED! 
===========================================================================
```

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
```powershell
flutter run --dart-define=API_URL=http://192.168.1.13:8000
```
