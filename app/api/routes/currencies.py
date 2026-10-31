from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.currency import (
    CurrencyConversionRequest,
    CurrencyConversionResponse,
    CurrencyListResponse,
    CurrencyRatesResponse,
)
from app.services.currency_service import CurrencyService

router = APIRouter(prefix="/currencies", tags=["Multi-Currency"])


@router.get(
    "",
    response_model=CurrencyListResponse,
    status_code=status.HTTP_200_OK,
    summary="List all supported application currencies"
)
def get_supported_currencies(
    db: Session = Depends(get_db)
) -> CurrencyListResponse:
    """
    Returns the 9 supported world currencies with their baseline exchange rates to PKR.
    """
    return CurrencyService.get_supported_currencies(db)


@router.get(
    "/rates",
    response_model=CurrencyRatesResponse,
    status_code=status.HTTP_200_OK,
    summary="Get verified exchange rates matrix"
)
def get_exchange_rates(
    db: Session = Depends(get_db)
) -> CurrencyRatesResponse:
    """
    Returns stored verified exchange rates.
    """
    return CurrencyService.get_all_rates(db)


@router.post(
    "/convert",
    response_model=CurrencyConversionResponse,
    status_code=status.HTTP_200_OK,
    summary="Convert an amount between supported currencies"
)
def convert_currency(
    req: CurrencyConversionRequest,
    db: Session = Depends(get_db)
) -> CurrencyConversionResponse:
    """
    Converts a monetary figure with full audit metadata.
    Never invents exchange rates silently.
    """
    converted, rate, eff_date, is_converted = CurrencyService.convert_amount(
        db=db,
        amount=req.amount,
        from_currency=req.from_currency,
        to_currency=req.to_currency
    )
    label = CurrencyService.format_conversion_label(
        original_amount=req.amount,
        original_currency=req.from_currency.upper(),
        converted_amount=converted,
        target_currency=req.to_currency.upper(),
        rate=rate
    )
    return CurrencyConversionResponse(
        original_amount=req.amount,
        original_currency=req.from_currency.upper(),
        converted_amount=converted,
        target_currency=req.to_currency.upper(),
        exchange_rate=rate,
        conversion_date=eff_date,
        is_converted=is_converted,
        label=label
    )
