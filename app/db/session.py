from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from app.core.config import settings
from app.db.base import Base
# Import all models here so Base.metadata knows about them
from app.models.user import User  # noqa: F401
from app.models.expense import Expense  # noqa: F401

# Configure connection arguments (check_same_thread needed for SQLite)
connect_args = {}
if settings.DATABASE_URL.startswith("sqlite"):
    connect_args["check_same_thread"] = False

engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def init_db() -> None:
    """
    Initialize database schema (creates tables if they do not exist).
    Phase 1 uses SQLite; Phase 2 will introduce Alembic migrations for PostgreSQL.
    """
    Base.metadata.create_all(bind=engine)


def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency that yields an active database session
    and ensures it is closed after request execution.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
