import base64
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
import json
import logging
from typing import Optional
import httpx

from app.core.config import settings
from app.schemas.expense import ExpenseCategory
from app.schemas.receipt import ReceiptLineItem, ReceiptScanResponse
from app.services.categorizer import SmartCategorizer
from app.services.receipt_providers.base import (
    BaseReceiptProvider,
    ProviderNotConfiguredError,
    ReceiptProviderError,
)

logger = logging.getLogger(__name__)

GEMINI_RECEIPT_PROMPT = """
You are an expert financial receipt analysis assistant. Analyze this receipt image and extract structured financial data into strict JSON format.

Allowed categories:
- Food (restaurants, cafes, groceries, bakeries, snacks, supermarkets)
- Transport (fuel, petrol, taxi, rideshare, parking, vehicle maintenance)
- Bills (electricity, gas, water, internet, phone, mobile recharge, utilities)
- Healthcare (pharmacies, medicines, clinics, doctor consultation, lab tests)
- Shopping (clothing, shoes, electronics, books, general retail)
- Education (school/college fees, books, courses, stationery)
- Entertainment (movies, games, streaming, events)
- Rent (housing, office, shop rent)
- Travel (flights, trains, intercity bus, hotels)
- Other (expenses that do not fit above)

Guidelines:
1. Extract the actual merchant or shop name. Return null if unreadable.
2. Extract the final TOTAL amount paid. Return null if total is missing or cut off.
3. Extract transaction date as 'YYYY-MM-DD'. If year is missing, assume current year. Return null if no date.
4. Currency defaults to 'PKR' unless indicated otherwise (e.g. USD, EUR, GBP, AED, SAR).
5. Suggest one of the exact allowed categories above, and explain your reasoning in 'category_explanation'.
6. List itemized goods/services in 'line_items' when clearly legible.
7. Provide confidence score (0.0 to 1.0) and include warnings for blurry text, folded receipt, or uncertain fields.
8. NEVER invent or hallucinate data. If unreadable, return null and note it in warnings.

Return ONLY a JSON object with this exact structure:
{
  "merchant_name": "string or null",
  "amount": 1234.50,
  "transaction_date": "YYYY-MM-DD or null",
  "currency": "PKR",
  "suggested_category": "Food",
  "category_explanation": "string explaining why",
  "line_items": [
    {"description": "Item 1", "amount": 100.0, "quantity": 1}
  ],
  "confidence": 0.95,
  "warnings": [],
  "raw_text_preview": "preview of key lines"
}
"""


class GeminiReceiptProvider(BaseReceiptProvider):
    """
    Receipt scanning provider powered by Google Gemini Vision.
    Calls Gemini API using httpx with strict structured JSON output.
    """

    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None):
        self.api_key = api_key if api_key is not None else settings.GEMINI_API_KEY
        self.model = model or settings.GEMINI_MODEL or "gemini-1.5-flash"

    @property
    def provider_name(self) -> str:
        return f"gemini ({self.model})"

    async def extract(
        self,
        image_bytes: bytes,
        mime_type: str,
        filename: Optional[str] = None
    ) -> ReceiptScanResponse:
        if not self.api_key or not self.api_key.strip():
            raise ProviderNotConfiguredError(
                "Gemini API key is not configured. Please set the GEMINI_API_KEY environment variable."
            )

        endpoint_url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/"
            f"{self.model}:generateContent?key={self.api_key}"
        )

        b64_image = base64.b64encode(image_bytes).decode("utf-8")

        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": GEMINI_RECEIPT_PROMPT},
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": b64_image
                            }
                        }
                    ]
                }
            ],
            "generationConfig": {
                "response_mime_type": "application/json",
                "temperature": 0.1
            }
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(endpoint_url, json=payload)
        except httpx.TimeoutException:
            raise ReceiptProviderError("AI vision request timed out. Please try again.", status_code=504)
        except httpx.RequestError as exc:
            raise ReceiptProviderError(f"Network error communicating with AI provider: {str(exc)}", status_code=502)

        if response.status_code == 400:
            logger.error("Gemini API rejected request: %s", response.text)
            raise ReceiptProviderError("AI provider rejected image format or payload.", status_code=400)
        elif response.status_code in (401, 403):
            raise ReceiptProviderError("Invalid or unauthorized Gemini API key.", status_code=502)
        elif response.status_code != 200:
            raise ReceiptProviderError(
                f"AI provider returned unexpected status {response.status_code}: {response.text[:200]}",
                status_code=502
            )

        try:
            res_data = response.json()
            candidates = res_data.get("candidates", [])
            if not candidates:
                raise ReceiptProviderError("AI vision provider returned no output candidates.")
            
            content_part = candidates[0].get("content", {}).get("parts", [{}])[0]
            raw_json_str = content_part.get("text", "{}")
            parsed = json.loads(raw_json_str)
        except Exception as e:
            logger.error("Failed to parse Gemini response: %s", e)
            raise ReceiptProviderError(f"Could not parse AI extraction result: {str(e)}")

        return self._build_scan_response(parsed)

    def _build_scan_response(self, data: dict) -> ReceiptScanResponse:
        # 1. Merchant Name
        merchant = data.get("merchant_name")
        if merchant and isinstance(merchant, str):
            merchant = merchant.strip()[:150]
        else:
            merchant = None

        # 2. Amount
        raw_amt = data.get("amount")
        amount = None
        if raw_amt is not None:
            try:
                dec = Decimal(str(raw_amt))
                if dec > Decimal("0.00"):
                    amount = dec.quantize(Decimal("0.01"))
            except (InvalidOperation, ValueError):
                amount = None

        # 3. Transaction Date
        date_str = data.get("transaction_date")
        trans_date = None
        if date_str and isinstance(date_str, str):
            try:
                trans_date = datetime.strptime(date_str.strip()[:10], "%Y-%m-%d").date()
            except ValueError:
                trans_date = None

        # 4. Currency
        currency = str(data.get("currency") or "PKR").upper()[:10]

        # 5. Suggested Category & Explanation
        cat_candidate = data.get("suggested_category")
        category_explanation = data.get("category_explanation")

        if cat_candidate and isinstance(cat_candidate, str):
            suggested_category = ExpenseCategory.normalize(cat_candidate)
            category_enum = ExpenseCategory(suggested_category)
        else:
            # Fallback to rule-based categorizer
            category_enum, category_explanation = SmartCategorizer.suggest_category(
                merchant_name=merchant,
                raw_text=data.get("raw_text_preview")
            )

        # 6. Line Items
        raw_items = data.get("line_items") or []
        line_items = []
        for item in raw_items:
            if isinstance(item, dict) and item.get("description"):
                desc = str(item["description"]).strip()[:200]
                item_amt = None
                if item.get("amount") is not None:
                    try:
                        item_amt = Decimal(str(item["amount"])).quantize(Decimal("0.01"))
                    except Exception:
                        item_amt = None
                qty = 1
                try:
                    qty = max(1, int(item.get("quantity", 1)))
                except Exception:
                    qty = 1
                line_items.append(ReceiptLineItem(description=desc, amount=item_amt, quantity=qty))

        # 7. Confidence & Warnings
        confidence = 0.8
        try:
            confidence = max(0.0, min(1.0, float(data.get("confidence", 0.8))))
        except Exception:
            confidence = 0.8

        warnings = list(data.get("warnings") or [])
        if amount is None:
            warnings.append("Could not confidently identify total amount from receipt.")
        if trans_date is None:
            warnings.append("Receipt date not detected; please verify the transaction date.")

        return ReceiptScanResponse(
            merchant_name=merchant,
            amount=amount,
            transaction_date=trans_date,
            currency=currency,
            suggested_category=category_enum,
            category_explanation=category_explanation,
            line_items=line_items,
            confidence=confidence,
            warnings=warnings,
            raw_text_preview=data.get("raw_text_preview"),
            provider_used=self.provider_name
        )
