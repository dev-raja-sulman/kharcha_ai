from typing import Optional
from fastapi import APIRouter, Depends, File, Query, UploadFile, status
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.receipt import ReceiptScanResponse
from app.services.receipt_service import ReceiptService

router = APIRouter(prefix="/receipts", tags=["Receipts"])


@router.post(
    "/scan",
    response_model=ReceiptScanResponse,
    status_code=status.HTTP_200_OK,
    summary="Scan Receipt Image with AI/OCR",
    description=(
        "Upload a receipt photo (JPEG, PNG, WebP up to 5MB). "
        "Extracts merchant name, total amount, transaction date, suggested category, "
        "and itemized lines using configured AI vision or OCR. "
        "Does NOT persist an expense; returns structured preview for user review."
    )
)
async def scan_receipt(
    file: UploadFile = File(..., description="Receipt image file (JPEG, PNG, or WebP)"),
    provider: Optional[str] = Query(
        None,
        description="Optional provider override: 'gemini' or 'rule_based'. Defaults to server configuration."
    ),
    current_user: User = Depends(get_current_user)
) -> ReceiptScanResponse:
    """
    Authenticated receipt scanning endpoint.
    Extracts structured expense fields without creating an expense record.
    """
    selected_provider = ReceiptService.get_provider(provider) if provider else None
    return await ReceiptService.process_receipt(upload_file=file, provider=selected_provider)
