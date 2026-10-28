from contextlib import asynccontextmanager
from datetime import datetime, timezone
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from app.api.api import api_router
from app.core.config import settings
from app.db.session import init_db
from app.schemas.auth import HealthResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan handler.
    Initializes database tables on startup and executes recurring expenses processing.
    """
    init_db()
    try:
        from app.db.session import SessionLocal
        from app.services.recurring_service import RecurringService
        with SessionLocal() as db:
            RecurringService.process_due_expenses(db)
    except Exception:
        pass
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.5.0",
    description="KharchaAI - AI-Powered Expense & Financial Management API (Phase 5: Recurring Expenses & Advanced Reports)",
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
    "/",
    response_class=HTMLResponse,
    tags=["System"],
    summary="KharchaAI Interactive Web App & Visual Testing Client"
)
def web_app():
    """
    Serves the interactive KharchaAI visual testing console directly in the browser.
    """
    html_path = os.path.join(os.path.dirname(__file__), "static", "web_app.html")
    if os.path.exists(html_path):
        with open(html_path, "r", encoding="utf-8") as f:
            return HTMLResponse(content=f.read())
    return HTMLResponse(content="<h1>KharchaAI Backend is Running</h1><p>Visit <a href='/docs'>/docs</a> for Swagger API.</p>")


@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["System"],
    summary="Service Health Check"
)
@app.get(
    "/api/v1/health",
    response_model=HealthResponse,
    tags=["System"],
    summary="Service Health Check (v1)"
)
def health_check() -> HealthResponse:
    """
    Health check endpoint returning system status, version, and database mode.
    Also verifies database connectivity.
    """
    from sqlalchemy import text
    from app.db.session import SessionLocal

    db_ok = True
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
    except Exception:
        db_ok = False

    db_mode = "SQLite (Local Development)" if "sqlite" in settings.DATABASE_URL else "PostgreSQL (Production)"
    return HealthResponse(
        status="healthy" if db_ok else "degraded",
        service=settings.PROJECT_NAME,
        version=settings.VERSION,
        timestamp=datetime.now(timezone.utc),
        database=db_mode
    )


if __name__ == "__main__":
    import uvicorn
    # Bind to 0.0.0.0 so both Android emulator (10.0.2.2) and local devices can connect
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
