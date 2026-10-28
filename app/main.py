from contextlib import asynccontextmanager
from datetime import datetime, timezone
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.api import api_router
from app.core.config import settings
from app.db.session import init_db
from app.schemas.auth import HealthResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan handler.
    Initializes database tables on startup.
    """
    # Initialize DB tables (Phase 1 uses SQLite, ready for Postgres in Phase 2)
    init_db()
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="KharchaAI - AI-Powered Expense & Financial Management API (Phase 1)",
    lifespan=lifespan
)

# Configure Cross-Origin Resource Sharing (CORS) for Flutter clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include v1 API routes
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["System"],
    summary="Service Health Check"
)
def health_check() -> HealthResponse:
    """
    Health check endpoint returning system status, version, and database mode.
    """
    db_mode = "SQLite (Local Development)" if "sqlite" in settings.DATABASE_URL else "PostgreSQL (Production)"
    return HealthResponse(
        status="healthy",
        service=settings.PROJECT_NAME,
        version=settings.VERSION,
        timestamp=datetime.now(timezone.utc),
        database=db_mode
    )


if __name__ == "__main__":
    import uvicorn
    # Bind to 0.0.0.0 so both Android emulator (10.0.2.2) and local devices can connect
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
