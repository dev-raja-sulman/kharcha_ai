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
    
    # Database Configuration
    # SQLite is used for local Phase 1 development; fully prepared for PostgreSQL in Phase 2
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./kharcha_dev.db")
    
    # CORS Configuration
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1",
        "http://10.0.2.2",
        "*"
    ]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
