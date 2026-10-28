import io
import logging
from typing import Optional
from fastapi import HTTPException, UploadFile, status
from PIL import Image

from app.core.config import settings
from app.schemas.receipt import ReceiptScanResponse
from app.services.receipt_providers.base import (
    BaseReceiptProvider,
    InvalidReceiptImageError,
    ProviderNotConfiguredError,
    ReceiptProviderError,
)
from app.services.receipt_providers.gemini_provider import GeminiReceiptProvider
from app.services.receipt_providers.rule_based_provider import RuleBasedReceiptProvider

logger = logging.getLogger(__name__)

# Magic byte signatures for client upload validation
IMAGE_SIGNATURES = {
    "jpeg": [b"\xff\xd8\xff"],
    "png": [b"\x89PNG\r\n\x1a\n"],
    "webp": [b"RIFF"]  # and "WEBP" at byte 8
}


class ReceiptService:
    """
    Service coordinating receipt validation, provider resolution,
    and structured AI/OCR processing.
    """

    @classmethod
    def get_provider(cls, name: Optional[str] = None) -> BaseReceiptProvider:
        provider_name = (name or settings.RECEIPT_AI_PROVIDER or "gemini").lower().strip()
        if provider_name == "rule_based":
            return RuleBasedReceiptProvider()
        elif provider_name == "gemini":
            return GeminiReceiptProvider()
        else:
            return GeminiReceiptProvider()

    @classmethod
    def get_default_provider(cls) -> BaseReceiptProvider:
        return cls.get_provider()

    @classmethod
    def validate_image_payload(cls, file_bytes: bytes, content_type: Optional[str]) -> str:
        """
        Validates content type, size limit, and binary signatures.
        Returns normalized mime type.
        """
        if not file_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded file is empty."
            )

        if len(file_bytes) > settings.RECEIPT_MAX_UPLOAD_BYTES:
            max_mb = settings.RECEIPT_MAX_UPLOAD_BYTES / (1024 * 1024)
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Uploaded image exceeds maximum allowable limit of {max_mb:.0f} MB."
            )

        mime = (content_type or "").lower().strip()
        if mime not in settings.RECEIPT_ALLOWED_MIME_TYPES:
            allowed = ", ".join(settings.RECEIPT_ALLOWED_MIME_TYPES)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported image format '{mime}'. Allowed formats: {allowed}"
            )

        # Inspect binary magic bytes
        is_valid_header = False
        if any(file_bytes.startswith(sig) for sig in IMAGE_SIGNATURES["jpeg"]):
            is_valid_header = True
        elif any(file_bytes.startswith(sig) for sig in IMAGE_SIGNATURES["png"]):
            is_valid_header = True
        elif file_bytes.startswith(b"RIFF") and len(file_bytes) > 12 and file_bytes[8:12] == b"WEBP":
            is_valid_header = True

        if not is_valid_header:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File content does not match a valid image binary signature."
            )

        # Validate with Pillow
        try:
            with Image.open(io.BytesIO(file_bytes)) as img:
                img.verify()
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="The uploaded file is corrupted or not a valid raster image."
            )

        return mime

    @classmethod
    async def process_receipt(
        cls,
        upload_file: UploadFile,
        provider: Optional[BaseReceiptProvider] = None
    ) -> ReceiptScanResponse:
        """
        Validates the upload, runs extraction via the configured provider,
        and returns the structured ReceiptScanResponse without writing to DB.
        """
        file_bytes = await upload_file.read()
        normalized_mime = cls.validate_image_payload(file_bytes, upload_file.content_type)

        active_provider = provider or cls.get_default_provider()

        try:
            result = await active_provider.extract(
                image_bytes=file_bytes,
                mime_type=normalized_mime,
                filename=upload_file.filename
            )
            return result
        except ProviderNotConfiguredError as e:
            logger.warning("Receipt AI provider is unconfigured: %s", e.message)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=e.message
            )
        except InvalidReceiptImageError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=e.message
            )
        except ReceiptProviderError as e:
            logger.error("Receipt extraction error: %s", e.message)
            raise HTTPException(
                status_code=e.status_code,
                detail=e.message
            )
        except Exception as e:
            logger.error("Unexpected error during receipt extraction: %s", str(e), exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="An unexpected internal error occurred during receipt analysis."
            )
