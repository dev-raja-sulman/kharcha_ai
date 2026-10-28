from abc import ABC, abstractmethod
from typing import Optional
from app.schemas.receipt import ReceiptScanResponse


class ReceiptProviderError(Exception):
    """General exception raised during receipt extraction."""
    def __init__(self, message: str, status_code: int = 502):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class ProviderNotConfiguredError(ReceiptProviderError):
    """Raised when an AI/OCR provider is chosen but missing required credentials."""
    def __init__(self, message: str = "Receipt AI provider is not configured or missing credentials."):
        super().__init__(message, status_code=503)


class InvalidReceiptImageError(ReceiptProviderError):
    """Raised when the uploaded file is corrupted, empty, or unreadable as an image."""
    def __init__(self, message: str = "The uploaded file could not be parsed as a valid image."):
        super().__init__(message, status_code=400)


class BaseReceiptProvider(ABC):
    """
    Abstract interface for receipt scanning and information extraction providers.
    """
    @property
    @abstractmethod
    def provider_name(self) -> str:
        """Unique identifier of the provider."""
        pass

    @abstractmethod
    async def extract(
        self,
        image_bytes: bytes,
        mime_type: str,
        filename: Optional[str] = None
    ) -> ReceiptScanResponse:
        """
        Processes receipt image bytes and extracts structured receipt data.
        """
        pass
