from datetime import date
from decimal import Decimal
from typing import List, Optional

from app.schemas.expense import ExpenseCategory
from app.schemas.receipt import ReceiptLineItem, ReceiptScanResponse
from app.services.receipt_providers.base import (
    BaseReceiptProvider,
    ReceiptProviderError,
)


class MockReceiptProvider(BaseReceiptProvider):
    """
    Mock provider for automated unit and integration tests.
    Allows testing failure handling, empty receipts, and successful parsing deterministically.
    """

    def __init__(
        self,
        should_fail: bool = False,
        failure_message: str = "Simulated upstream provider outage",
        merchant_name: Optional[str] = "Al-Fatah Supermarket",
        amount: Optional[Decimal] = Decimal("4850.50"),
        transaction_date: Optional[date] = None,
        suggested_category: ExpenseCategory = ExpenseCategory.FOOD,
        category_explanation: Optional[str] = "Suggested as Food based on identified terms: 'supermarket'",
        line_items: Optional[List[ReceiptLineItem]] = None,
        confidence: float = 0.94,
        warnings: Optional[List[str]] = None
    ):
        self.should_fail = should_fail
        self.failure_message = failure_message
        self.merchant_name = merchant_name
        self.amount = amount
        self.transaction_date = transaction_date or date.today()
        self.suggested_category = suggested_category
        self.category_explanation = category_explanation
        self.line_items = line_items or [
            ReceiptLineItem(description="Cooking Oil 5L", amount=Decimal("2850.00"), quantity=1),
            ReceiptLineItem(description="Basmati Rice 5kg", amount=Decimal("2000.50"), quantity=1)
        ]
        self.confidence = confidence
        self.warnings = warnings or []

    @property
    def provider_name(self) -> str:
        return "mock"

    async def extract(
        self,
        image_bytes: bytes,
        mime_type: str,
        filename: Optional[str] = None
    ) -> ReceiptScanResponse:
        if self.should_fail:
            raise ReceiptProviderError(self.failure_message, status_code=502)

        return ReceiptScanResponse(
            merchant_name=self.merchant_name,
            amount=self.amount,
            transaction_date=self.transaction_date,
            currency="PKR",
            suggested_category=self.suggested_category,
            category_explanation=self.category_explanation,
            line_items=self.line_items,
            confidence=self.confidence,
            warnings=self.warnings,
            raw_text_preview="Al-Fatah Supermarket Lahore\nDate: 2026-10-28\nTotal: PKR 4,850.50",
            provider_used=self.provider_name
        )
