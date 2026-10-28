from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, EmailStr, Field


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


class UserLoginRequest(BaseModel):
    """
    Schema for user login request.
    """
    email: EmailStr = Field(..., description="Registered email address")
    password: str = Field(..., description="Account password")


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
