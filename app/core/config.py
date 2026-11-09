import os
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Application Settings for KharchaAI.
    Loads configurations from environment variables or .env file.
    """
    PROJECT_NAME: str = "KharchaAI API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Security & JWT Configuration
    # In production, SECRET_KEY must be overridden by a strong random key in .env
    SECRET_KEY: str = os.getenv("SECRET_KEY", "kharcha_ai_dev_secret_key_change_in_production_9f83a21b4e")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours for local development convenience
    
    PORT: int = int(os.getenv("PORT", 8000))

    # Database Configuration
    # SQLite is used for local Phase 1 development; fully prepared for PostgreSQL in Phase 2
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./kharcha_dev.db")

    @property
    def SQLALCHEMY_DATABASE_URL(self) -> str:
        """
        Normalizes database URL for SQLAlchemy 2.0 with psycopg v3.
        Translates 'postgres://' or 'postgresql://' into 'postgresql+psycopg://'.
        """
        url = self.DATABASE_URL
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+psycopg://", 1)
        if url.startswith("postgresql://") and not url.startswith("postgresql+"):
            return url.replace("postgresql://", "postgresql+psycopg://", 1)
        return url
    
    # CORS Configuration
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1",
        "http://10.0.2.2",
        "*"
    ]

    # AI & Receipt Scanning Configuration
    # Supported providers: "gemini", "rule_based", "mock"
    RECEIPT_AI_PROVIDER: str = os.getenv("RECEIPT_AI_PROVIDER", "gemini")
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
    RECEIPT_MAX_UPLOAD_BYTES: int = 5 * 1024 * 1024  # 5 MB maximum image size
    RECEIPT_ALLOWED_MIME_TYPES: List[str] = [
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp"
    ]

    # Email & SMTP Delivery Configuration
    # Supports Gmail, Outlook, Yahoo, SendGrid, Resend, or custom SMTP
    SMTP_HOST: str = os.getenv("SMTP_HOST", "")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", 587))
    SMTP_USER: str = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    EMAILS_FROM_EMAIL: str = os.getenv("EMAILS_FROM_EMAIL", "no-reply@kharcha.ai")
    EMAILS_FROM_NAME: str = os.getenv("EMAILS_FROM_NAME", "KharchaAI Security")
    SMTP_TLS: bool = os.getenv("SMTP_TLS", "true").lower() in ("true", "1", "yes")
    SMTP_SSL: bool = os.getenv("SMTP_SSL", "false").lower() in ("true", "1", "yes")

    # OTP Security Parameters
    OTP_EXPIRE_MINUTES: int = 5          # Exact 5 minutes validity
    OTP_COOLDOWN_SECONDS: int = 60       # 60-second cooldown between resends
    OTP_MAX_ATTEMPTS: int = 5            # Protection against brute-force (max 5 incorrect tries)
    OTP_MAX_RESENDS_PER_HOUR: int = 5    # Resend rate-limiting

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
