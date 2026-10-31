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
