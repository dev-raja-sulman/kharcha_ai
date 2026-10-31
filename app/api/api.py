from fastapi import APIRouter
from app.api.routes import (
    analytics,
    auth,
    bills,
    budgets,
    currencies,
    dashboard,
    expenses,
    financial_advisor,
    incomes,
    receipts,
    recurring,
    reports,
    saving_goals,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(currencies.router)
api_router.include_router(dashboard.router)
api_router.include_router(expenses.router)
api_router.include_router(incomes.router)
api_router.include_router(incomes.sources_router)
api_router.include_router(saving_goals.router)
api_router.include_router(bills.router)
api_router.include_router(financial_advisor.router)
api_router.include_router(receipts.router)
api_router.include_router(budgets.router)
api_router.include_router(analytics.router)
api_router.include_router(recurring.router)
api_router.include_router(reports.router)



