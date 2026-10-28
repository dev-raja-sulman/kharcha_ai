# KharchaAI — Phase 1: Authentication & Integration

KharchaAI is an AI-powered personal expense tracker and financial management app. This repository contains the complete **Phase 1** implementation: modular FastAPI authentication backend integrated with a production-grade Flutter frontend.

---

## 📁 Project Architecture

```
Karcha AI App/
├── app/                                 # FastAPI Backend (Modular Architecture)
│   ├── api/
│   │   ├── deps.py                      # JWT Bearer token dependency (get_current_user)
│   │   ├── api.py                       # v1 router registry
│   │   └── routes/
│   │       └── auth.py                  # Endpoints: /register, /login, /me
│   ├── core/
│   │   ├── config.py                    # Settings & environment variables (pydantic-settings)
│   │   └── security.py                  # Direct bcrypt hashing & JWT encoding/decoding
│   ├── db/
│   │   ├── base.py                      # SQLAlchemy declarative base
│   │   └── session.py                   # Engine, SessionLocal, init_db, get_db generator
│   ├── models/
│   │   └── user.py                      # User model (id, email, hashed_password, full_name, is_active, timestamps)
│   ├── schemas/
│   │   └── auth.py                      # Request/Response schemas with strict Pydantic validation
│   ├── services/
│   │   └── auth_service.py              # Business logic: registration, authentication, profile lookups
│   ├── tests/                           # Pytest automated test suite
│   │   ├── conftest.py                  # In-memory test SQLite session & client fixture
│   │   ├── test_health.py               # Health endpoint test
│   │   └── test_auth.py                 # 9 comprehensive security & auth tests
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
│   │   └── auth_response.dart           # Token response wrapper
│   ├── services/
│   │   └── auth_service.dart            # Flutter authentication API consumer
│   ├── widgets/
│   │   ├── custom_button.dart           # Loading state & styled action button
│   │   └── custom_text_field.dart       # Form field with validation & password visibility toggle
│   ├── screens/
│   │   ├── splash_screen.dart           # Auto-checks token & navigates to Dashboard or Login
│   │   ├── login_screen.dart            # Login form with validation & error banner
│   │   ├── register_screen.dart         # Sign-up form with password confirmation
│   │   ├── dashboard_screen.dart        # Financial overview, status card & session controls
│   │   └── profile_screen.dart          # User account details & logout dialog
│   └── main.dart                        # App bootstrap & theme setup
├── scripts/
│   └── verify_api_integration.py        # Automated end-to-end 10-point integration check
├── test/                                # Flutter Unit Tests
│   ├── models_test.dart
│   └── api_config_test.dart
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

## 🧪 Automated Test Results

### 1. Backend Pytest Suite
Ran: `python -m pytest app/tests -v`
```
app/tests/test_auth.py::test_register_success PASSED                     [ 10%]
app/tests/test_auth.py::test_register_duplicate_email PASSED             [ 20%]
app/tests/test_auth.py::test_register_invalid_input PASSED               [ 30%]
app/tests/test_auth.py::test_login_success PASSED                        [ 40%]
app/tests/test_auth.py::test_login_invalid_password PASSED               [ 50%]
app/tests/test_auth.py::test_login_unregistered_email PASSED             [ 60%]
app/tests/test_auth.py::test_get_current_user_profile PASSED             [ 70%]
app/tests/test_auth.py::test_get_current_user_unauthorized PASSED        [ 80%]
app/tests/test_auth.py::test_password_never_stored_in_plaintext PASSED   [ 90%]
app/tests/test_health.py::test_health_check PASSED                       [100%]
======================== 10 passed in 4.48s ========================
```

### 2. Live End-to-End API Integration
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
[PASS] Step 9: Database Security Audit -> Bcrypt Hash $2b$12$... Verified (Zero plaintext)
[PASS] Step 10: Network Failure Resilience Check -> Connection refusal mapped to friendly message
```

---

## 🗄️ Database Note: Phase 1 vs Phase 2
- **Phase 1 (Development):** Uses SQLite (`sqlite:///./kharcha_dev.db`). This allows zero-friction local development without requiring external database services.
- **Phase 2 (Production):** The SQLAlchemy models and `DATABASE_URL` setting are designed to switch seamlessly to **PostgreSQL** by updating `.env` (e.g. `DATABASE_URL=postgresql+psycopg://user:pass@localhost:5432/kharcha_ai`).
