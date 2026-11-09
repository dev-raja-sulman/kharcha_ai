from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import create_access_token
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    ResendOtpRequest,
    ResendOtpResponse,
    ResetPasswordRequest,
    SocialLoginRequest,
    TokenResponse,
    UserCurrencyUpdateRequest,
    UserLoginRequest,
    UserRegisterRequest,
    UserResponse,
    UserUpdateRequest,
    VerifyEmailRequest,
    VerifyOtpRequest,
    VerifyOtpResponse,
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
    Dispatches a 6-digit verification code to the entered email address.
    Returns the user profile with is_email_verified=False and a pending JWT access token.
    """
    user = AuthService.register_user(db, req)
    token = create_access_token(subject=user.email)

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse.model_validate(user)
    )


@router.post(
    "/verify-email",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify user email address using 6-digit OTP"
)
def verify_email(
    req: VerifyEmailRequest,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """
    Verifies the user's email with the 6-digit OTP code sent to their inbox.
    Activates the account and unlocks protected features.
    """
    user = AuthService.verify_email_otp(db, req.email, req.otp)
    token = create_access_token(subject=user.email)

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse.model_validate(user)
    )


@router.post(
    "/resend-otp",
    response_model=ResendOtpResponse,
    status_code=status.HTTP_200_OK,
    summary="Resend a 6-digit verification OTP code"
)
def resend_otp(
    req: ResendOtpRequest,
    db: Session = Depends(get_db)
) -> ResendOtpResponse:
    """
    Dispatches a new 6-digit verification code with 60-second cooldown enforcement.
    """
    AuthService.resend_verification_otp(db, req.email, req.purpose)
    return ResendOtpResponse(
        message="A new 6-digit verification code has been sent to your email address.",
        email=req.email,
        cooldown_seconds=60
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


@router.post(
    "/forgot-password",
    response_model=ForgotPasswordResponse,
    status_code=status.HTTP_200_OK,
    summary="Request a 6-digit OTP code to reset password"
)
def forgot_password(
    req: ForgotPasswordRequest,
    db: Session = Depends(get_db)
) -> ForgotPasswordResponse:
    """
    Generates a secure 6-digit OTP for the registered email address.
    Strictly delivers via email; code is not exposed in response body.
    """
    AuthService.generate_password_reset_otp(db, req.email)
    return ForgotPasswordResponse(
        message="A 6-digit verification code has been sent to your email address.",
        email=req.email,
        expires_in_seconds=300
    )


@router.post(
    "/verify-otp",
    response_model=VerifyOtpResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify 6-digit password reset OTP"
)
def verify_otp(
    req: VerifyOtpRequest,
    db: Session = Depends(get_db)
) -> VerifyOtpResponse:
    """
    Validates that the provided 6-digit OTP is correct and has not expired.
    """
    AuthService.verify_password_reset_otp(db, req.email, req.otp)
    return VerifyOtpResponse(
        valid=True,
        message="Verification code is valid. You may now reset your password."
    )


@router.post(
    "/reset-password",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Reset password using verified OTP"
)
def reset_password(
    req: ResetPasswordRequest,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """
    Resets the account password and automatically logs the user in with a new JWT access token.
    """
    user = AuthService.reset_password_with_otp(
        db=db,
        email=req.email,
        otp=req.otp,
        new_password=req.new_password
    )
    token = create_access_token(subject=user.email)
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse.model_validate(user)
    )


@router.post(
    "/social-login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Authenticate or register using Google or Apple sign-in"
)
def social_login(
    req: SocialLoginRequest,
    db: Session = Depends(get_db)
) -> TokenResponse:
    """
    Handles 1-tap sign-in and account provisioning for Google and Apple identities.
    """
    user = AuthService.authenticate_or_create_social_user(
        db=db,
        provider=req.provider,
        email=req.email,
        name=req.name
    )
    token = create_access_token(subject=user.email)
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse.model_validate(user)
    )
