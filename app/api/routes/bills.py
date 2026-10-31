from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.bill import Bill
from app.models.user import User
from app.schemas.bill import (
    BillCreate,
    BillListResponse,
    BillResponse,
    BillSummaryResponse,
    BillUpdate,
    MarkPaidRequest,
)
from app.services.bill_service import BillService

router = APIRouter(prefix="/bills", tags=["Bills"])


def _to_bill_response(b: Bill) -> BillResponse:
    return BillResponse(
        id=b.id,
        user_id=b.user_id,
        title=b.title,
        category=b.category,
        amount=b.amount,
        due_date=b.due_date,
        status=b.status,
        frequency=b.frequency,
        reminder_enabled=b.reminder_enabled,
        paid_date=b.paid_date,
        linked_expense_id=b.linked_expense_id,
        is_overdue=b.is_overdue,
        created_at=b.created_at,
        updated_at=b.updated_at,
    )


@router.post(
    "",
    response_model=BillResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new bill"
)
def create_bill(
    bill_in: BillCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BillResponse:
    bill = BillService.create_bill(
        db=db,
        user_id=current_user.id,
        bill_in=bill_in
    )
    return _to_bill_response(bill)


@router.get(
    "",
    response_model=BillListResponse,
    summary="List all bills with optional status and category filters"
)
def list_bills(
    status: Optional[str] = Query(None, description="Filter by status: unpaid | paid | overdue"),
    category: Optional[str] = Query(None, description="Filter by category"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BillListResponse:
    bills, total_amount = BillService.get_bills(
        db=db,
        user_id=current_user.id,
        status_filter=status,
        category=category
    )
    return BillListResponse(
        total=len(bills),
        total_amount=total_amount,
        items=[_to_bill_response(b) for b in bills]
    )


@router.get(
    "/upcoming",
    response_model=List[BillResponse],
    summary="Get upcoming unpaid or overdue bills due within N days"
)
def get_upcoming_bills(
    days: int = Query(14, ge=1, le=90, description="Window in days to check for upcoming bills"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[BillResponse]:
    bills = BillService.get_upcoming_bills(
        db=db,
        user_id=current_user.id,
        days=days
    )
    return [_to_bill_response(b) for b in bills]


@router.get(
    "/summary",
    response_model=BillSummaryResponse,
    summary="Get summary metrics for bills (pending, overdue, paid this month, upcoming)"
)
def get_bill_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BillSummaryResponse:
    return BillService.get_summary(
        db=db,
        user_id=current_user.id
    )


@router.get(
    "/{bill_id}",
    response_model=BillResponse,
    summary="Get details for a specific bill"
)
def get_bill(
    bill_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BillResponse:
    bill = BillService.get_bill_by_id(
        db=db,
        user_id=current_user.id,
        bill_id=bill_id
    )
    return _to_bill_response(bill)


@router.put(
    "/{bill_id}",
    response_model=BillResponse,
    summary="Update a bill"
)
def update_bill(
    bill_id: int,
    bill_in: BillUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BillResponse:
    bill = BillService.update_bill(
        db=db,
        user_id=current_user.id,
        bill_id=bill_id,
        bill_in=bill_in
    )
    return _to_bill_response(bill)


@router.delete(
    "/{bill_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a bill"
)
def delete_bill(
    bill_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> None:
    BillService.delete_bill(
        db=db,
        user_id=current_user.id,
        bill_id=bill_id
    )


@router.post(
    "/{bill_id}/mark-paid",
    response_model=BillResponse,
    summary="Mark a bill as paid with optional expense record synchronization"
)
def mark_bill_as_paid(
    bill_id: int,
    req: MarkPaidRequest = MarkPaidRequest(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> BillResponse:
    bill = BillService.mark_as_paid(
        db=db,
        user_id=current_user.id,
        bill_id=bill_id,
        req=req
    )
    return _to_bill_response(bill)
