from datetime import datetime, timedelta, timezone
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.otp import EmailOTP
from app.models.user import User


def test_registration_creates_unverified_user_and_otp(client: TestClient, db_session: Session):
    """
    Test that registering a new user creates an unverified user (is_email_verified=False)
    and generates an EmailOTP record with a 5-minute expiry.
    """
    email = "new_verify_user@kharcha.ai"
    res = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "ValidPassword123!",
        "full_name": "Verify Me"
    })
    assert res.status_code == 201
    data = res.json()
    assert data["user"]["email"] == email
    assert data["user"]["is_email_verified"] is False

    # Check user in DB
    user = db_session.query(User).filter(User.email == email).first()
    assert user is not None
    assert user.is_email_verified is False

    # Check OTP record in DB
    otp_record = db_session.query(EmailOTP).filter(
        EmailOTP.email == email,
        EmailOTP.purpose == "registration"
    ).first()
    assert otp_record is not None
    assert otp_record.is_used is False
    assert otp_record.attempts == 0
    now = datetime.now(timezone.utc)
    exp = otp_record.expires_at
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    assert exp > now
    # Expiry is within 5 minutes
    assert exp <= now + timedelta(minutes=5, seconds=5)


def test_verify_email_success(client: TestClient, db_session: Session):
    """
    Test verifying an email with the correct 6-digit OTP succeeds,
    marks is_email_verified = True, and marks OTP as used.
    """
    email = "verify_success@kharcha.ai"
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "ValidPassword123!",
        "full_name": "Success User"
    })

    # Generate a known OTP in DB for testing
    otp_code = "729401"
    otp_record = db_session.query(EmailOTP).filter(EmailOTP.email == email).first()
    otp_record.otp_hash = EmailOTP.hash_otp(otp_code)
    db_session.commit()

    # Call verify-email endpoint
    verify_res = client.post("/api/v1/auth/verify-email", json={
        "email": email,
        "otp": otp_code
    })
    assert verify_res.status_code == 200
    res_data = verify_res.json()
    assert res_data["user"]["is_email_verified"] is True
    assert "access_token" in res_data

    # Verify DB state
    db_session.refresh(otp_record)
    assert otp_record.is_used is True

    user = db_session.query(User).filter(User.email == email).first()
    assert user.is_email_verified is True


def test_verify_email_incorrect_code(client: TestClient, db_session: Session):
    """
    Test that entering an incorrect OTP increments attempts and returns remaining attempts.
    """
    email = "wrong_code@kharcha.ai"
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "ValidPassword123!"
    })

    # Try invalid code
    bad_res = client.post("/api/v1/auth/verify-email", json={
        "email": email,
        "otp": "000000"
    })
    assert bad_res.status_code == 400
    assert "remaining" in bad_res.json()["detail"].lower()

    otp_record = db_session.query(EmailOTP).filter(EmailOTP.email == email).first()
    assert otp_record.attempts == 1


def test_verify_email_lockout_after_max_attempts(client: TestClient, db_session: Session):
    """
    Test that exceeding 5 incorrect attempts locks the OTP.
    """
    email = "lockout_test@kharcha.ai"
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "ValidPassword123!"
    })

    otp_record = db_session.query(EmailOTP).filter(EmailOTP.email == email).first()
    otp_record.attempts = 5
    db_session.commit()

    # Attempt verification when attempts already >= max
    res = client.post("/api/v1/auth/verify-email", json={
        "email": email,
        "otp": "123456"
    })
    assert res.status_code == 400
    assert "too many incorrect attempts" in res.json()["detail"].lower()


def test_verify_email_expired_code(client: TestClient, db_session: Session):
    """
    Test that an expired OTP (> 5 minutes old) is rejected.
    """
    email = "expired_code@kharcha.ai"
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "ValidPassword123!"
    })

    otp_record = db_session.query(EmailOTP).filter(EmailOTP.email == email).first()
    otp_record.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
    db_session.commit()

    res = client.post("/api/v1/auth/verify-email", json={
        "email": email,
        "otp": "123456"
    })
    assert res.status_code == 400
    assert "expired" in res.json()["detail"].lower()


def test_resend_otp_cooldown(client: TestClient, db_session: Session):
    """
    Test that requesting a new OTP within 60 seconds triggers a 429 Too Many Requests
    with cooldown information.
    """
    email = "cooldown_test@kharcha.ai"
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "ValidPassword123!"
    })

    # Immediate resend should trigger 429
    res = client.post("/api/v1/auth/resend-otp", json={
        "email": email,
        "purpose": "registration"
    })
    assert res.status_code == 429
    assert "seconds before requesting" in res.json()["detail"]


def test_resend_otp_after_cooldown(client: TestClient, db_session: Session):
    """
    Test that requesting a new OTP after 60 seconds succeeds.
    """
    email = "resend_after_cooldown@kharcha.ai"
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "ValidPassword123!"
    })

    # Age the last_sent_at past 60s
    otp_record = db_session.query(EmailOTP).filter(EmailOTP.email == email).first()
    otp_record.last_sent_at = datetime.now(timezone.utc) - timedelta(seconds=65)
    db_session.commit()

    res = client.post("/api/v1/auth/resend-otp", json={
        "email": email,
        "purpose": "registration"
    })
    assert res.status_code == 200
    assert res.json()["cooldown_seconds"] == 60


def test_forgot_password_case_insensitive_and_no_dev_otp(client: TestClient, db_session: Session):
    """
    Test that forgot password finds users case-insensitively and never exposes dev_otp.
    """
    email = "rajasulman_case@kharcha.ai"
    client.post("/api/v1/auth/register", json={
        "email": email,
        "password": "InitialPassword123!",
        "full_name": "Case Test"
    })

    # Age the registration OTP to avoid any cooldown conflicts
    db_session.query(EmailOTP).filter(EmailOTP.email == email).update({
        "last_sent_at": datetime.now(timezone.utc) - timedelta(seconds=70)
    })
    db_session.commit()

    # Query with uppercase / mixed case email
    res = client.post("/api/v1/auth/forgot-password", json={
        "email": "RajaSulman_Case@kharcha.ai"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["expires_in_seconds"] == 300
    # Zero exposure: dev_otp must NOT be in response
    assert "dev_otp" not in data or data.get("dev_otp") is None

    # Retrieve generated OTP from DB and reset password
    otp_record = db_session.query(EmailOTP).filter(
        EmailOTP.email == email,
        EmailOTP.purpose == "password_reset"
    ).first()
    assert otp_record is not None
    test_code = "834190"
    otp_record.otp_hash = EmailOTP.hash_otp(test_code)
    db_session.commit()

    # Reset password with OTP
    reset_res = client.post("/api/v1/auth/reset-password", json={
        "email": email,
        "otp": test_code,
        "new_password": "BrandNewPassword123!"
    })
    assert reset_res.status_code == 200
    assert "access_token" in reset_res.json()

    # Verify user can log in with new password
    login_res = client.post("/api/v1/auth/login", json={
        "email": email,
        "password": "BrandNewPassword123!"
    })
    assert login_res.status_code == 200
