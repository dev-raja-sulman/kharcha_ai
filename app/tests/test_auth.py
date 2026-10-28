from datetime import timedelta
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, verify_password
from app.models.user import User


def test_register_success(client: TestClient):
    """
    Verify successful user registration returns 201, token, and user info.
    """
    payload = {
        "email": "user@kharcha.ai",
        "password": "SecurePassword123!",
        "full_name": "Raja Sulman"
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == "user@kharcha.ai"
    assert data["user"]["full_name"] == "Raja Sulman"
    assert data["user"]["is_active"] is True
    assert "id" in data["user"]
    # Ensure password is not exposed in response
    assert "password" not in data["user"]
    assert "hashed_password" not in data["user"]


def test_register_duplicate_email(client: TestClient):
    """
    Verify registering with an existing email returns 400 Bad Request.
    """
    payload = {
        "email": "duplicate@kharcha.ai",
        "password": "Password123",
        "full_name": "First User"
    }
    # First registration
    res1 = client.post("/api/v1/auth/register", json=payload)
    assert res1.status_code == 201

    # Second registration with same email
    res2 = client.post("/api/v1/auth/register", json=payload)
    assert res2.status_code == 400
    assert "already exists" in res2.json()["detail"]


def test_register_invalid_input(client: TestClient):
    """
    Verify schema validation rejects invalid email or short password (< 6 chars).
    """
    # Invalid email format
    res_bad_email = client.post("/api/v1/auth/register", json={
        "email": "not-an-email",
        "password": "ValidPassword123"
    })
    assert res_bad_email.status_code == 422

    # Short password
    res_short_pw = client.post("/api/v1/auth/register", json={
        "email": "short@kharcha.ai",
        "password": "123"
    })
    assert res_short_pw.status_code == 422


def test_login_success(client: TestClient):
    """
    Verify valid credentials return 200 OK and JWT access token.
    """
    # Register first
    client.post("/api/v1/auth/register", json={
        "email": "login_test@kharcha.ai",
        "password": "MySecretPassword123",
        "full_name": "Login Tester"
    })

    # Attempt login
    response = client.post("/api/v1/auth/login", json={
        "email": "login_test@kharcha.ai",
        "password": "MySecretPassword123"
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["email"] == "login_test@kharcha.ai"
    assert data["user"]["full_name"] == "Login Tester"


def test_login_invalid_password(client: TestClient):
    """
    Verify incorrect password returns 401 Unauthorized.
    """
    client.post("/api/v1/auth/register", json={
        "email": "wrong_pw@kharcha.ai",
        "password": "CorrectPassword123"
    })

    response = client.post("/api/v1/auth/login", json={
        "email": "wrong_pw@kharcha.ai",
        "password": "IncorrectPassword999"
    })
    assert response.status_code == 401
    assert "Invalid email or password" in response.json()["detail"]


def test_login_unregistered_email(client: TestClient):
    """
    Verify non-existent user login returns 401 Unauthorized.
    """
    response = client.post("/api/v1/auth/login", json={
        "email": "doesnotexist@kharcha.ai",
        "password": "SomePassword123"
    })
    assert response.status_code == 401
    assert "Invalid email or password" in response.json()["detail"]


def test_get_current_user_profile(client: TestClient):
    """
    Verify GET /api/v1/auth/me returns the authenticated user profile with Bearer token.
    """
    # Register user
    reg_res = client.post("/api/v1/auth/register", json={
        "email": "me_test@kharcha.ai",
        "password": "SecretPassword123",
        "full_name": "Profile Owner"
    })
    token = reg_res.json()["access_token"]

    # Request /me with Bearer token
    headers = {"Authorization": f"Bearer {token}"}
    me_res = client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 200
    user_data = me_res.json()
    assert user_data["email"] == "me_test@kharcha.ai"
    assert user_data["full_name"] == "Profile Owner"
    assert user_data["is_active"] is True


def test_get_current_user_unauthorized(client: TestClient):
    """
    Verify GET /api/v1/auth/me rejects unauthenticated, invalid, or expired tokens.
    """
    # Missing token
    res_no_token = client.get("/api/v1/auth/me")
    assert res_no_token.status_code == 401

    # Malformed token
    res_bad_token = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer not_a_real_jwt_token"}
    )
    assert res_bad_token.status_code == 401

    # Expired token
    expired_token = create_access_token(
        subject="expired@kharcha.ai",
        expires_delta=timedelta(seconds=-10)
    )
    res_expired = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {expired_token}"}
    )
    assert res_expired.status_code == 401


def test_password_never_stored_in_plaintext(client: TestClient, db_session: Session):
    """
    Verify that user passwords are NEVER stored in plaintext in the database.
    Directly query the database row and inspect hashed_password.
    """
    raw_password = "SuperSecretPlainTextPassword2026!"
    email = "plain_check@kharcha.ai"

    # Register via API
    res = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": raw_password,
        "full_name": "Plain Text Auditor"
    })
    assert res.status_code == 201

    # Query DB row directly
    db_user = db_session.query(User).filter(User.email == email).first()
    assert db_user is not None

    # Verification assertions:
    # 1. Stored value does NOT equal raw password
    assert db_user.hashed_password != raw_password
    # 2. Raw password is not even a substring
    assert raw_password not in db_user.hashed_password
    # 3. Hash starts with standard bcrypt prefix ($2a$ or $2b$)
    assert db_user.hashed_password.startswith("$2b$") or db_user.hashed_password.startswith("$2a$")
    # 4. Verifying via bcrypt succeeds
    assert verify_password(raw_password, db_user.hashed_password) is True
