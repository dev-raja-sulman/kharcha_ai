from datetime import date
from decimal import Decimal
import io
import re
from typing import Optional
from PIL import Image

from app.schemas.expense import ExpenseCategory
from app.schemas.receipt import ReceiptScanResponse
from app.services.categorizer import SmartCategorizer
from app.services.receipt_providers.base import (
    BaseReceiptProvider,
    InvalidReceiptImageError,
)


class RuleBasedReceiptProvider(BaseReceiptProvider):
    """
    Deterministic rule-based fallback provider.
    Verifies image integrity using Pillow and provides heuristic extraction
    when external cloud AI vision keys are unconfigured.
    """

    @property
    def provider_name(self) -> str:
        return "rule_based"

    async def extract(
        self,
        image_bytes: bytes,
        mime_type: str,
        filename: Optional[str] = None
    ) -> ReceiptScanResponse:
        if not image_bytes or len(image_bytes) < 10:
            raise InvalidReceiptImageError("Uploaded file is empty or corrupted.")

        # Validate with Pillow
        try:
            image = Image.open(io.BytesIO(image_bytes))
            image.verify()
            # Reopen to check dimensions (verify closes the file handle)
            image = Image.open(io.BytesIO(image_bytes))
            width, height = image.size
            if width < 30 or height < 30:
                raise InvalidReceiptImageError("Image dimensions are too small to be a legible receipt.")
        except InvalidReceiptImageError:
            raise
        except Exception as e:
            raise InvalidReceiptImageError(f"Cannot decode receipt image: {str(e)}")

        warnings = [
            "Processed using local rule-based engine. Review all fields before saving.",
            "AI vision provider is not configured; automated optical character recognition is limited."
        ]

        # Extract filename cues if available
        merchant_name = None
        extracted_amount = None
        clean_name = filename.rsplit(".", 1)[0] if filename else ""

        # Check if filename contains hints (e.g., "kfc_1500.jpg", "shell_fuel_receipt.png")
        if clean_name:
            # Check for numbers in filename as potential amount
            amount_match = re.search(r"(\d+(?:\.\d{1,2})?)", clean_name)
            if amount_match:
                try:
                    val = Decimal(amount_match.group(1))
                    if Decimal("1.00") <= val <= Decimal("1000000.00"):
                        extracted_amount = val.quantize(Decimal("0.01"))
                except Exception:
                    pass

            # Filter clean words for merchant
            words = [w for w in re.split(r"[_\-\s\.]+", clean_name) if not w.isdigit()]
            if words:
                candidate = " ".join(words).title()
                if len(candidate) > 2 and candidate.lower() not in ("receipt", "image", "photo", "scan", "img"):
                    merchant_name = candidate

        category, explanation = SmartCategorizer.suggest_category(
            merchant_name=merchant_name,
            raw_text=clean_name
        )

        if extracted_amount is None:
            warnings.append("Total amount was not detected. Please enter the amount manually.")

        return ReceiptScanResponse(
            merchant_name=merchant_name,
            amount=extracted_amount,
            transaction_date=date.today(),
            currency="PKR",
            suggested_category=category,
            category_explanation=explanation,
            line_items=[],
            confidence=0.45 if (merchant_name or extracted_amount) else 0.20,
            warnings=warnings,
            raw_text_preview=f"Image verified ({width}x{height} {image.format}). Filename: {filename or 'receipt'}",
            provider_used=self.provider_name
        )
