from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator


# ---------------------------------------------------------------------------
# Request Schemas
# ---------------------------------------------------------------------------

class UserRegisterRequest(BaseModel):
    """
    Schema for user registration request.
    Validates email format, password length, and optional full name.
    """
    email: EmailStr = Field(..., description="Valid email address of the user")
    password: str = Field(
        ...,
        min_length=6,
        max_length=128,
        description="Password (minimum 6 characters)"
    )
    full_name: Optional[str] = Field(
        None,
        max_length=100,
        description="Optional full name or display name"
    )
    preferred_currency: Optional[str] = Field(
        "PKR",
        min_length=3,
        max_length=10,
        description="User preferred display currency (defaults to PKR)"
    )


class UserCurrencyUpdateRequest(BaseModel):
    """
    Schema for updating user preferred display currency.
    """
    currency: Optional[str] = Field(None, min_length=3, max_length=10, description="ISO Currency code, e.g. PKR, USD, EUR")
    preferred_currency: Optional[str] = Field(None, min_length=3, max_length=10, description="Alias for currency")

    @model_validator(mode="after")
    def validate_currency_field(self) -> "UserCurrencyUpdateRequest":
        selected = self.currency or self.preferred_currency
        if not selected:
            raise ValueError("Either 'currency' or 'preferred_currency' must be provided")
        self.currency = selected
        return self


class UserUpdateRequest(BaseModel):
    """
    Schema for updating user profile settings.
    """
    full_name: Optional[str] = Field(None, max_length=100)
    preferred_currency: Optional[str] = Field(None, min_length=3, max_length=10)


class UserLoginRequest(BaseModel):
    """
    Schema for user login request.
    """
    email: EmailStr = Field(..., description="Registered email address")
    password: str = Field(..., description="Account password")


class ForgotPasswordRequest(BaseModel):
    """
    Schema for requesting a 6-digit password reset OTP to email.
    """
    email: EmailStr = Field(..., description="Email address associated with the account")


class ForgotPasswordResponse(BaseModel):
    """
    Response confirming OTP generation.
    """
    message: str
    email: str
    expires_in_seconds: int = 600
    # For convenient dev/testing mode on local/staging
    dev_otp: Optional[str] = None


class VerifyOtpRequest(BaseModel):
    """
    Schema for verifying the 6-digit OTP code sent to user email.
    """
    email: EmailStr = Field(..., description="User email address")
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit verification code")


class VerifyOtpResponse(BaseModel):
    """
    Response for OTP verification.
    """
    valid: bool
    message: str


class ResetPasswordRequest(BaseModel):
    """
    Schema for finalizing password reset using verified OTP.
    """
    email: EmailStr = Field(..., description="User email address")
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit verification code")
    new_password: str = Field(
        ...,
        min_length=6,
        max_length=128,
        description="New password (minimum 6 characters)"
    )


class SocialLoginRequest(BaseModel):
    """
    Schema for Google and Apple social sign-in.
    """
    provider: str = Field(..., description="Provider name ('google' or 'apple')")
    email: EmailStr = Field(..., description="User email verified by provider")
    name: Optional[str] = Field(None, description="User full name from provider profile")
    token: Optional[str] = Field(None, description="OAuth ID token or provider user ID")


# ---------------------------------------------------------------------------
# Response Schemas
# ---------------------------------------------------------------------------

class UserResponse(BaseModel):
    """
    Public user representation returned by authentication endpoints.
    Never exposes hashed password or internal security tokens.
    """
    id: int
    email: str
    full_name: Optional[str] = None
    is_active: bool
    preferred_currency: str = "PKR"
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TokenResponse(BaseModel):
    """
    Schema returned upon successful registration or login.
    """
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class HealthResponse(BaseModel):
    """
    Health check response model.
    """
    status: str
    service: str
    version: str
    timestamp: datetime
    database: str
