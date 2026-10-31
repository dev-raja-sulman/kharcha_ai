from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import create_access_token
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    TokenResponse,
    UserCurrencyUpdateRequest,
    UserLoginRequest,
    UserRegisterRequest,
    UserResponse,
    UserUpdateRequest,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user account"
)
def register(
    req: UserRegisterRequest,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """
    Register a new user with email, password, and optional full name.
    Returns the created user profile and a JWT access token.
    """
    user = AuthService.register_user(db, req)
    token = create_access_token(subject=user.email)

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse.model_validate(user)
    )


@router.post(
    "/login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Log in with email and password"
)
def login(
    req: UserLoginRequest,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """
    Authenticate user credentials.
    Returns an access token and user profile on success.
    """
    user = AuthService.authenticate_user(db, req.email, req.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password. Please try again.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(subject=user.email)

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse.model_validate(user)
    )


@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current authenticated user profile"
)
def get_current_user_profile(
    current_user: User = Depends(get_current_user)
) -> UserResponse:
    """
    Retrieve the profile of the currently authenticated user.
    Requires a valid JWT Bearer token in the Authorization header.
    """
    return UserResponse.model_validate(current_user)


@router.patch(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Update current user profile and preferences"
)
@router.put(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Update current user profile and preferences"
)
def update_current_user_profile(
    req: UserUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> UserResponse:
    """
    Update profile attributes such as full_name or preferred_currency.
    """
    updated_user = AuthService.update_user_profile(
        db=db,
        user=current_user,
        full_name=req.full_name,
        preferred_currency=req.preferred_currency
    )
    return UserResponse.model_validate(updated_user)


@router.put(
    "/currency",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Update preferred display currency"
)
def update_currency_preference(
    req: UserCurrencyUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> UserResponse:
    """
    Save user's preferred display currency (e.g. PKR, USD, EUR, etc.).
    """
    updated_user = AuthService.update_user_currency(
        db=db,
        user=current_user,
        currency=req.currency
    )
    return UserResponse.model_validate(updated_user)
