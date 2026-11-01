from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.core.security import hash_password, verify_password
from app.models.user import User
from app.schemas.auth import UserRegisterRequest


class AuthService:
    """
    Business logic service for user authentication, registration,
    and profile management.
    """

    @staticmethod
    def get_user_by_email(db: Session, email: str) -> Optional[User]:
        """
        Query a user by normalized email address.
        """
        normalized_email = email.strip().lower()
        return db.query(User).filter(User.email == normalized_email).first()

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
        Raises 400 Bad Request if the email is already in use.
        """
        normalized_email = req.email.strip().lower()

        # Check existing user
        existing_user = AuthService.get_user_by_email(db, normalized_email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="An account with this email address already exists."
            )

        # Hash password securely
        hashed_pwd = hash_password(req.password)

        pref_currency = req.preferred_currency.upper().strip() if req.preferred_currency else "PKR"

        new_user = User(
            email=normalized_email,
            hashed_password=hashed_pwd,
            full_name=req.full_name.strip() if req.full_name else None,
            preferred_currency=pref_currency,
            is_active=True
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
    def generate_password_reset_otp(db: Session, email: str):
        """
        Generates a secure 6-digit OTP for password reset with a 10-minute expiry window.
        """
        import secrets
        from datetime import datetime, timedelta, timezone
        from app.models.otp import PasswordResetOTP

        normalized_email = email.strip().lower()
        user = AuthService.get_user_by_email(db, normalized_email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No registered account found with this email address."
            )

        # Invalidate previous unused OTPs for this email
        db.query(PasswordResetOTP).filter(
            PasswordResetOTP.email == normalized_email,
            PasswordResetOTP.is_used == False
        ).update({"is_used": True})

        # Generate a 6-digit cryptographic code
        code = f"{secrets.randbelow(900000) + 100000}"
        now_utc = datetime.now(timezone.utc)
        expires_at = now_utc + timedelta(minutes=10)

        otp_record = PasswordResetOTP(
            email=normalized_email,
            otp_code=code,
            expires_at=expires_at,
            is_used=False
        )
        db.add(otp_record)
        db.commit()
        db.refresh(otp_record)

        # Log OTP to server console for testing/debugging
        print(f"\n==========================================")
        print(f"🔑 [KharchaAI OTP] Code for {normalized_email}: {code} (Valid for 10 min)")
        print(f"==========================================\n")

        return otp_record, code

    @staticmethod
    def verify_password_reset_otp(db: Session, email: str, otp: str) -> bool:
        """
        Validates the 6-digit OTP code against the database.
        """
        from datetime import datetime, timezone
        from app.models.otp import PasswordResetOTP

        normalized_email = email.strip().lower()
        clean_code = otp.strip()

        record = db.query(PasswordResetOTP).filter(
            PasswordResetOTP.email == normalized_email,
            PasswordResetOTP.otp_code == clean_code,
            PasswordResetOTP.is_used == False
        ).order_by(PasswordResetOTP.id.desc()).first()

        if not record:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid verification code. Please check and try again."
            )

        now = datetime.now(timezone.utc)
        exp = record.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)

        if now > exp:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This verification code has expired. Please request a new one."
            )

        return True

    @staticmethod
    def reset_password_with_otp(db: Session, email: str, otp: str, new_password: str) -> User:
        """
        Resets user password after OTP validation.
        """
        from app.models.otp import PasswordResetOTP

        normalized_email = email.strip().lower()
        # Verify first
        AuthService.verify_password_reset_otp(db, normalized_email, otp)

        user = AuthService.get_user_by_email(db, normalized_email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User account not found."
            )

        # Mark OTP as used
        db.query(PasswordResetOTP).filter(
            PasswordResetOTP.email == normalized_email,
            PasswordResetOTP.otp_code == otp.strip()
        ).update({"is_used": True})

        user.hashed_password = hash_password(new_password)
        db.commit()
        db.refresh(user)
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
        """
        import secrets

        normalized_email = email.strip().lower()
        user = AuthService.get_user_by_email(db, normalized_email)

        if user:
            if not user.is_active:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="This account has been deactivated. Please contact support."
                )
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
            is_active=True
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        return new_user
