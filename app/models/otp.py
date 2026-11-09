import hashlib
import hmac
from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String
from app.core.config import settings
from app.db.base import Base


class EmailOTP(Base):
    """
    Model for managing secure 6-digit email OTPs for registration verification
    and password reset.
    Stores cryptographically hashed OTPs so plain-text codes are never stored in DB.
    """
    __tablename__ = "email_otps"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), index=True, nullable=False)
    otp_hash = Column(String(255), nullable=False)
    purpose = Column(String(50), default="registration", nullable=False)  # "registration" or "password_reset"
    expires_at = Column(DateTime(timezone=True), nullable=False)
    attempts = Column(Integer, default=0, nullable=False)
    is_used = Column(Boolean, default=False, nullable=False)
    resend_count = Column(Integer, default=0, nullable=False)
    last_sent_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    @staticmethod
    def hash_otp(code: str) -> str:
        """
        Computes HMAC-SHA256 hash using application SECRET_KEY as pepper.
        Guarantees raw OTP codes cannot be reversed if database is inspected.
        """
        secret_bytes = settings.SECRET_KEY.encode("utf-8")
        code_bytes = code.strip().encode("utf-8")
        return hmac.new(secret_bytes, code_bytes, hashlib.sha256).hexdigest()

    def verify_code(self, candidate_code: str) -> bool:
        """
        Constant-time verification of candidate OTP code against stored hash.
        """
        candidate_hash = self.hash_otp(candidate_code)
        return hmac.compare_digest(self.otp_hash, candidate_hash)

    def is_valid(self) -> bool:
        """
        Returns True if the OTP is unused, not locked (> max attempts), and not expired.
        """
        now = datetime.now(timezone.utc)
        exp = self.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        
        return (
            not self.is_used
            and self.attempts < settings.OTP_MAX_ATTEMPTS
            and exp > now
        )

    def __repr__(self) -> str:
        return f"<EmailOTP email='{self.email}' purpose='{self.purpose}' is_used={self.is_used}>"


# Backwards compatibility class for older migrations/references
class PasswordResetOTP(Base):
    """
    Deprecated legacy table model for password reset OTPs.
    Maintained for backward compatibility with existing migrations.
    """
    __tablename__ = "password_reset_otps"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    email = Column(String(255), index=True, nullable=False)
    otp_code = Column(String(6), nullable=False)
    is_used = Column(Boolean, default=False, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    def is_valid(self) -> bool:
        now = datetime.now(timezone.utc)
        exp = self.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        return not self.is_used and exp > now
