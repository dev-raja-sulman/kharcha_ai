from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String
from app.db.base import Base


class PasswordResetOTP(Base):
    """
    Model for managing 6-digit email OTPs for password reset.
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
        """Returns True if the OTP is unused and not expired."""
        now = datetime.now(timezone.utc)
        # Ensure expires_at has timezone info
        exp = self.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        return not self.is_used and exp > now

    def __repr__(self) -> str:
        return f"<PasswordResetOTP email='{self.email}' is_used={self.is_used}>"
