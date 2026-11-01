import pytest
from fastapi.testclient import TestClient


def test_forgot_password_flow(client: TestClient):
    # 1. Register a user
    reg_payload = {
        "email": "otptest@kharcha.ai",
        "password": "OldPassword123!",
        "full_name": "OTP User"
    }
    reg_res = client.post("/api/v1/auth/register", json=reg_payload)
    assert reg_res.status_code == 201

    # 2. Request OTP for password reset
    forgot_payload = {"email": "otptest@kharcha.ai"}
    forgot_res = client.post("/api/v1/auth/forgot-password", json=forgot_payload)
    assert forgot_res.status_code == 200
    forgot_data = forgot_res.json()
    assert "dev_otp" in forgot_data
    otp_code = forgot_data["dev_otp"]
    assert len(otp_code) == 6

    # 3. Verify incorrect OTP
    bad_verify = client.post("/api/v1/auth/verify-otp", json={
        "email": "otptest@kharcha.ai",
        "otp": "000000"
    })
    assert bad_verify.status_code == 400

    # 4. Verify correct OTP
    good_verify = client.post("/api/v1/auth/verify-otp", json={
        "email": "otptest@kharcha.ai",
        "otp": otp_code
    })
    assert good_verify.status_code == 200
    assert good_verify.json()["valid"] is True

    # 5. Reset password with valid OTP
    reset_res = client.post("/api/v1/auth/reset-password", json={
        "email": "otptest@kharcha.ai",
        "otp": otp_code,
        "new_password": "NewSecretPassword456!"
    })
    assert reset_res.status_code == 200
    reset_data = reset_res.json()
    assert "access_token" in reset_data

    # 6. Verify login with NEW password
    login_new = client.post("/api/v1/auth/login", json={
        "email": "otptest@kharcha.ai",
        "password": "NewSecretPassword456!"
    })
    assert login_new.status_code == 200

    # 7. Verify login with OLD password fails
    login_old = client.post("/api/v1/auth/login", json={
        "email": "otptest@kharcha.ai",
        "password": "OldPassword123!"
    })
    assert login_old.status_code == 401


def test_forgot_password_nonexistent_email(client: TestClient):
    res = client.post("/api/v1/auth/forgot-password", json={
        "email": "nonexistent_email_12345@kharcha.ai"
    })
    assert res.status_code == 404


def test_social_login(client: TestClient):
    # Google social login
    google_res = client.post("/api/v1/auth/social-login", json={
        "provider": "google",
        "email": "google_user@gmail.com",
        "name": "Google Tester",
        "token": "mock_google_id_token"
    })
    assert google_res.status_code == 200
    google_data = google_res.json()
    assert "access_token" in google_data
    assert google_data["user"]["email"] == "google_user@gmail.com"
    assert google_data["user"]["full_name"] == "Google Tester"

    # Apple social login
    apple_res = client.post("/api/v1/auth/social-login", json={
        "provider": "apple",
        "email": "apple_user@icloud.com",
        "name": "Apple Tester",
        "token": "mock_apple_token"
    })
    assert apple_res.status_code == 200
    apple_data = apple_res.json()
    assert "access_token" in apple_data
    assert apple_data["user"]["email"] == "apple_user@icloud.com"
