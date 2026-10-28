from datetime import date
from decimal import Decimal
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

from app.schemas.expense import ExpenseCategory


class ReceiptLineItem(BaseModel):
    description: str = Field(..., min_length=1, max_length=200)
    amount: Optional[Decimal] = Field(default=None, decimal_places=2, max_digits=12)
    quantity: Optional[int] = Field(default=1, ge=1)

    model_config = ConfigDict(from_attributes=True)


class ReceiptScanResponse(BaseModel):
    """
    Structured extraction response from AI/OCR receipt scan.
    Does NOT create an expense in the database; returned to client for review and confirmation.
    """
    merchant_name: Optional[str] = Field(
        default=None,
        max_length=150,
        description="Identified store or merchant name, or null if unidentifiable"
    )
    amount: Optional[Decimal] = Field(
        default=None,
        gt=Decimal("0.00"),
        decimal_places=2,
        max_digits=12,
        description="Extracted total expense amount, or null if uncertain"
    )
    transaction_date: Optional[date] = Field(
        default=None,
        description="Extracted transaction date, or null if uncertain"
    )
    currency: str = Field(
        default="PKR",
        max_length=10,
        description="Currency code (e.g. PKR, USD)"
    )
    suggested_category: ExpenseCategory = Field(
        default=ExpenseCategory.OTHER,
        description="AI-suggested expense category based on merchant and items"
    )
    category_explanation: Optional[str] = Field(
        default=None,
        max_length=300,
        description="Reasoning behind category suggestion"
    )
    line_items: List[ReceiptLineItem] = Field(
        default_factory=list,
        description="Itemized receipt line items if identifiable"
    )
    confidence: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Overall extraction confidence score between 0.0 and 1.0"
    )
    warnings: List[str] = Field(
        default_factory=list,
        description="Field-level uncertainties or scanning advisories"
    )
    raw_text_preview: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Preview of parsed text lines from receipt"
    )
    provider_used: str = Field(
        default="gemini",
        description="Identifier of the AI or OCR provider that processed this receipt"
    )

    model_config = ConfigDict(from_attributes=True)
