from fastapi import APIRouter
from app.api.routes import analytics, auth, budgets, expenses, incomes, receipts, recurring, reports

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(expenses.router)
api_router.include_router(incomes.router)
api_router.include_router(incomes.sources_router)
api_router.include_router(receipts.router)
api_router.include_router(budgets.router)
api_router.include_router(analytics.router)
api_router.include_router(recurring.router)
api_router.include_router(reports.router)

