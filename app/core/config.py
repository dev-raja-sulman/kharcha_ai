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

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
