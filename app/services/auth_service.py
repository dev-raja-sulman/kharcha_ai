import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password, verify_password
from app.models.otp import EmailOTP, PasswordResetOTP
from app.models.user import User
from app.schemas.auth import UserRegisterRequest
from app.services.email_service import EmailService


class AuthService:
    """
    Business logic service for user authentication, registration,
    email verification, and profile management.
    """

    @staticmethod
    def get_user_by_email(db: Session, email: str) -> Optional[User]:
        """
        Query a user by normalized email address.
        Uses case-insensitive and whitespace-trimmed matching to prevent lookup discrepancies.
        """
        if not email:
            return None
        normalized_email = email.strip().lower()
        return db.query(User).filter(
            func.lower(func.trim(User.email)) == normalized_email
        ).first()

    @staticmethod
    def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
        """
        Query a user by primary key ID.
        """
        return db.query(User).filter(User.id == user_id).first()

    @staticmethod
    def register_user(db: Session, req: UserRegisterRequest) -> User:
        """
        Register a new user in the system.
        If the account is already verified, raises 400 Bad Request.
        If an unverified account exists with this email, updates details and dispatches a fresh OTP.
        Generates a 6-digit OTP and sends verification email.
        """
        normalized_email = req.email.strip().lower()
        existing_user = AuthService.get_user_by_email(db, normalized_email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="An account with this email address already exists. Please log in."
            )

        hashed_pwd = hash_password(req.password)
        pref_currency = req.preferred_currency.upper().strip() if req.preferred_currency else "PKR"
        user_name = req.full_name.strip() if req.full_name else None

        user = User(
            email=normalized_email,
            hashed_password=hashed_pwd,
            full_name=user_name,
            preferred_currency=pref_currency,
            is_active=True,
            is_email_verified=False
        )
        db.add(user)

        db.commit()
        db.refresh(user)

        # Invalidate previous unused registration OTPs for this email
        db.query(EmailOTP).filter(
            EmailOTP.email == normalized_email,
            EmailOTP.purpose == "registration",
            EmailOTP.is_used == False
        ).update({"is_used": True})

        # Generate secure random 6-digit OTP code
        otp_code = f"{secrets.randbelow(900000) + 100000}"
        now_utc = datetime.now(timezone.utc)
        expires_at = now_utc + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

        otp_record = EmailOTP(
            email=normalized_email,
            otp_hash=EmailOTP.hash_otp(otp_code),
            purpose="registration",
            expires_at=expires_at,
            attempts=0,
            is_used=False,
            resend_count=0,
            last_sent_at=now_utc,
            created_at=now_utc
        )
        db.add(otp_record)

        # Send verification email via EmailService before committing
        EmailService.send_otp_email(
            to_email=normalized_email,
            otp_code=otp_code,
            purpose="registration"
        )

        db.commit()
        return user

    @staticmethod
    def verify_email_otp(db: Session, email: str, otp: str) -> User:
        """
        Validates the 6-digit registration OTP code.
        Marks the user account as verified upon success.
        Enforces 5-minute expiry and max 5 attempts lockout.
        """
        normalized_email = email.strip().lower()
        user = AuthService.get_user_by_email(db, normalized_email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No account found with this email address."
            )

        if user.is_email_verified:
            return user

        # Retrieve the latest active registration OTP record
        record = db.query(EmailOTP).filter(
            EmailOTP.email == normalized_email,
            EmailOTP.purpose == "registration",
            EmailOTP.is_used == False
        ).order_by(EmailOTP.id.desc()).first()

        if not record:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No active verification code found for this email. Please tap 'Resend Code'."
            )

        # Check maximum attempts limit
        if record.attempts >= settings.OTP_MAX_ATTEMPTS:
            record.is_used = True
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Too many incorrect attempts. For security, please request a new verification code."
            )

        # Check expiration
        now_utc = datetime.now(timezone.utc)
        exp = record.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)

        if now_utc > exp:
            record.is_used = True
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This verification code has expired. Please tap 'Resend Code'."
            )

        # Verify candidate code against HMAC-SHA256 hash
        if not record.verify_code(otp.strip()):
            record.attempts += 1
            db.commit()
            remaining = settings.OTP_MAX_ATTEMPTS - record.attempts
            if remaining > 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid verification code. {remaining} attempt(s) remaining."
                )
            else:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Too many incorrect attempts. Please request a new verification code."
                )

        # Success - Mark OTP used and User email verified
        record.is_used = True
        user.is_email_verified = True
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def resend_verification_otp(
        db: Session,
        email: str,
        purpose: str = "registration"
    ) -> None:
        """
        Resends a fresh 6-digit OTP code to the user's email.
        Strictly enforces 60-second cooldown and hourly resend rate limits.
        """
        normalized_email = email.strip().lower()
        now_utc = datetime.now(timezone.utc)

        user = AuthService.get_user_by_email(db, normalized_email)
        if purpose == "registration":
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="No registration pending for this email address."
                )
            if user.is_email_verified:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="This email address is already verified. Please log in."
                )
        elif purpose == "password_reset":
            if not user:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="No registered account found with this email address."
                )

        # Check recent OTP for cooldown
        last_otp = db.query(EmailOTP).filter(
            EmailOTP.email == normalized_email,
            EmailOTP.purpose == purpose
        ).order_by(EmailOTP.id.desc()).first()

        if last_otp:
            last_sent = last_otp.last_sent_at
            if last_sent.tzinfo is None:
                last_sent = last_sent.replace(tzinfo=timezone.utc)
            elapsed_seconds = (now_utc - last_sent).total_seconds()

            if elapsed_seconds < settings.OTP_COOLDOWN_SECONDS:
                remaining = int(settings.OTP_COOLDOWN_SECONDS - elapsed_seconds)
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Please wait {remaining} seconds before requesting a new code."
                )

            # Check hourly resend rate limits
            one_hour_ago = now_utc - timedelta(hours=1)
            recent_resends = db.query(EmailOTP).filter(
                EmailOTP.email == normalized_email,
                EmailOTP.purpose == purpose,
                EmailOTP.created_at >= one_hour_ago
            ).count()

            if recent_resends >= settings.OTP_MAX_RESENDS_PER_HOUR:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="You have reached the maximum number of code requests for this hour. Please try again later."
                )

        # Invalidate previous unused OTPs
        db.query(EmailOTP).filter(
            EmailOTP.email == normalized_email,
            EmailOTP.purpose == purpose,
            EmailOTP.is_used == False
        ).update({"is_used": True})

        # Generate new 6-digit code
        otp_code = f"{secrets.randbelow(900000) + 100000}"
        expires_at = now_utc + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

        new_otp = EmailOTP(
            email=normalized_email,
            otp_hash=EmailOTP.hash_otp(otp_code),
            purpose=purpose,
            expires_at=expires_at,
            attempts=0,
            is_used=False,
            resend_count=(last_otp.resend_count + 1) if last_otp else 1,
            last_sent_at=now_utc,
            created_at=now_utc
        )
        db.add(new_otp)

        # Send email before committing
        EmailService.send_otp_email(
            to_email=normalized_email,
            otp_code=otp_code,
            purpose=purpose
        )

        db.commit()

    @staticmethod
    def generate_password_reset_otp(db: Session, email: str) -> Tuple[EmailOTP, str]:
        """
        Generates a secure 6-digit OTP for password reset with a 5-minute expiry window.
        Enforces 60-second cooldown to prevent spamming.
        """
        normalized_email = email.strip().lower()
        now_utc = datetime.now(timezone.utc)

        user = AuthService.get_user_by_email(db, normalized_email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No registered account found with this email address."
            )

        # Check cooldown
        last_otp = db.query(EmailOTP).filter(
            EmailOTP.email == normalized_email,
            EmailOTP.purpose == "password_reset"
        ).order_by(EmailOTP.id.desc()).first()

        if last_otp:
            last_sent = last_otp.last_sent_at
            if last_sent.tzinfo is None:
                last_sent = last_sent.replace(tzinfo=timezone.utc)
            elapsed_seconds = (now_utc - last_sent).total_seconds()
            if elapsed_seconds < settings.OTP_COOLDOWN_SECONDS:
                remaining = int(settings.OTP_COOLDOWN_SECONDS - elapsed_seconds)
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Please wait {remaining} seconds before requesting a new code."
                )

        # Invalidate previous unused OTPs
        db.query(EmailOTP).filter(
            EmailOTP.email == normalized_email,
            EmailOTP.purpose == "password_reset",
            EmailOTP.is_used == False
        ).update({"is_used": True})

        # Generate 6-digit cryptographic code
        code = f"{secrets.randbelow(900000) + 100000}"
        expires_at = now_utc + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)

        otp_record = EmailOTP(
            email=normalized_email,
            otp_hash=EmailOTP.hash_otp(code),
            purpose="password_reset",
            expires_at=expires_at,
            attempts=0,
            is_used=False,
            resend_count=(last_otp.resend_count + 1) if last_otp else 0,
            last_sent_at=now_utc,
            created_at=now_utc
        )
        db.add(otp_record)

        # Send password reset email before committing
        EmailService.send_otp_email(
            to_email=normalized_email,
            otp_code=code,
            purpose="password_reset"
        )

        db.commit()
        db.refresh(otp_record)

        return otp_record, code

    @staticmethod
    def verify_password_reset_otp(db: Session, email: str, otp: str) -> bool:
        """
        Validates the 6-digit password reset OTP code.
        """
        normalized_email = email.strip().lower()
        now_utc = datetime.now(timezone.utc)

        record = db.query(EmailOTP).filter(
            EmailOTP.email == normalized_email,
            EmailOTP.purpose == "password_reset",
            EmailOTP.is_used == False
        ).order_by(EmailOTP.id.desc()).first()

        # Fallback to legacy table if exists during migration transition
        if not record:
            legacy_record = db.query(PasswordResetOTP).filter(
                PasswordResetOTP.email == normalized_email,
                PasswordResetOTP.otp_code == otp.strip(),
                PasswordResetOTP.is_used == False
            ).order_by(PasswordResetOTP.id.desc()).first()

            if legacy_record and legacy_record.is_valid():
                return True

            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid verification code. Please check and try again."
            )

        if record.attempts >= settings.OTP_MAX_ATTEMPTS:
            record.is_used = True
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Too many incorrect attempts. Please request a new verification code."
            )

        exp = record.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)

        if now_utc > exp:
            record.is_used = True
            db.commit()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This verification code has expired. Please request a new one."
            )

        if not record.verify_code(otp.strip()):
            record.attempts += 1
            db.commit()
            remaining = settings.OTP_MAX_ATTEMPTS - record.attempts
            if remaining > 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid verification code. {remaining} attempt(s) remaining."
                )
            else:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Too many incorrect attempts. Please request a new verification code."
                )

        return True

    @staticmethod
    def reset_password_with_otp(db: Session, email: str, otp: str, new_password: str) -> User:
        """
        Resets user password after OTP validation.
        Also marks email verified since user proved control of email.
        """
        normalized_email = email.strip().lower()
        AuthService.verify_password_reset_otp(db, normalized_email, otp)

        user = AuthService.get_user_by_email(db, normalized_email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User account not found."
            )

        # Mark OTP as used
        db.query(EmailOTP).filter(
            EmailOTP.email == normalized_email,
            EmailOTP.purpose == "password_reset",
            EmailOTP.is_used == False
        ).update({"is_used": True})

        # Also mark any legacy OTP as used
        db.query(PasswordResetOTP).filter(
            PasswordResetOTP.email == normalized_email,
            PasswordResetOTP.is_used == False
        ).update({"is_used": True})

        user.hashed_password = hash_password(new_password)
        user.is_email_verified = True
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def authenticate_user(
        db: Session,
        email: str,
        password: str
    ) -> Optional[User]:
        """
        Validate credentials for user login.
        Returns the User object if valid, None if credentials do not match.
        Raises 403 Forbidden if the account is deactivated.
        """
        user = AuthService.get_user_by_email(db, email)
        if not user:
            return None

        if not verify_password(password, user.hashed_password):
            return None

        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="This account has been deactivated. Please contact support."
            )

        return user

    @staticmethod
    def authenticate_or_create_social_user(
        db: Session,
        provider: str,
        email: str,
        name: Optional[str] = None
    ) -> User:
        """
        Authenticates an existing user via Google/Apple or creates a new one.
        Social logins are automatically marked as verified since OAuth providers verify email.
        """
        normalized_email = email.strip().lower()
        user = AuthService.get_user_by_email(db, normalized_email)

        if user:
            if not user.is_active:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="This account has been deactivated. Please contact support."
                )
            # Ensure social sign-ins have email verified
            if not user.is_email_verified:
                user.is_email_verified = True
            if not user.full_name and name:
                user.full_name = name.strip()
            db.commit()
            db.refresh(user)
            return user

        # Create new user for social login
        random_pwd = secrets.token_urlsafe(24)
        new_user = User(
            email=normalized_email,
            hashed_password=hash_password(random_pwd),
            full_name=name.strip() if name else f"{provider.capitalize()} User",
            preferred_currency="PKR",
            is_active=True,
            is_email_verified=True
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user

    @staticmethod
    def update_user_currency(db: Session, user: User, currency: str) -> User:
        """
        Updates the preferred display currency for the user.
        """
        from app.models.currency import SupportedCurrency
        clean_code = currency.upper().strip()
        if not SupportedCurrency.is_valid(clean_code):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Currency '{currency}' is not supported. Supported: {', '.join(SupportedCurrency.ALL)}"
            )

        user.preferred_currency = clean_code
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def update_user_profile(
        db: Session,
        user: User,
        full_name: Optional[str] = None,
        preferred_currency: Optional[str] = None
    ) -> User:
        """
        Updates profile fields (full_name, preferred_currency) for the user.
        """
        from app.models.currency import SupportedCurrency
        if full_name is not None:
            user.full_name = full_name.strip() if full_name.strip() else None

        if preferred_currency is not None:
            clean_code = preferred_currency.upper().strip()
            if not SupportedCurrency.is_valid(clean_code):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Currency '{preferred_currency}' is not supported. Supported: {', '.join(SupportedCurrency.ALL)}"
                )
            user.preferred_currency = clean_code

        db.commit()
        db.refresh(user)
        return user
