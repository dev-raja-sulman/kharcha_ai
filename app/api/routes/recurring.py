from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.expense import ExpenseResponse
from app.schemas.recurring import (
    RecurringExpenseCreateRequest,
    RecurringExpenseListResponse,
    RecurringExpenseResponse,
    RecurringExpenseUpdateRequest,
    RecurringProcessResponse,
)
from app.services.recurring_service import RecurringService

router = APIRouter(prefix="/recurring-expenses", tags=["Recurring Expenses"])


@router.post(
    "",
    response_model=RecurringExpenseResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a recurring expense rule"
)
def create_recurring_rule(
    req: RecurringExpenseCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringExpenseResponse:
    """
    Creates a new recurring expense rule (Daily, Weekly, Monthly, Yearly).
    Strictly tied to the authenticated user.
    """
    rule = RecurringService.create_rule(
        db=db,
        user_id=current_user.id,
        req=req
    )
    return RecurringExpenseResponse.model_validate(rule)


@router.get(
    "",
    response_model=RecurringExpenseListResponse,
    summary="List all recurring expense rules"
)
def list_recurring_rules(
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status: active, paused, cancelled, completed"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringExpenseListResponse:
    """
    Retrieves all recurring expense rules for the authenticated user.
    """
    rules = RecurringService.get_user_rules(
        db=db,
        user_id=current_user.id,
        status_filter=status_filter
    )
    items = [RecurringExpenseResponse.model_validate(r) for r in rules]
    return RecurringExpenseListResponse(items=items, total=len(items))


@router.post(
    "/process",
    response_model=RecurringProcessResponse,
    summary="Process due recurring expenses"
)
def process_due_recurring_expenses(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringProcessResponse:
    """
    Idempotent trigger to check and generate expenses for rules due on or before today.
    Runs strictly within the authenticated user's workspace.
    """
    processed, generated = RecurringService.process_due_expenses(
        db=db,
        user_id=current_user.id
    )
    return RecurringProcessResponse(
        processed_rules=processed,
        generated_count=generated,
        message=f"Processed {processed} recurring rules. Generated {generated} new expenses."
    )


@router.get(
    "/{id}",
    response_model=RecurringExpenseResponse,
    summary="Get recurring expense rule details"
)
def get_recurring_rule(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringExpenseResponse:
    """
    Retrieves details for a single recurring rule.
    """
    rule = RecurringService.get_rule_by_id(
        db=db,
        user_id=current_user.id,
        rule_id=id
    )
    return RecurringExpenseResponse.model_validate(rule)


@router.put(
    "/{id}",
    response_model=RecurringExpenseResponse,
    summary="Update a recurring expense rule"
)
def update_recurring_rule(
    id: int,
    req: RecurringExpenseUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringExpenseResponse:
    """
    Updates rule parameters like title, amount, category, frequency, and end date.
    """
    rule = RecurringService.update_rule(
        db=db,
        user_id=current_user.id,
        rule_id=id,
        req=req
    )
    return RecurringExpenseResponse.model_validate(rule)


@router.post(
    "/{id}/pause",
    response_model=RecurringExpenseResponse,
    summary="Pause a recurring expense rule"
)
def pause_recurring_rule(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringExpenseResponse:
    """
    Pauses an active recurring rule so no new expenses are automatically generated.
    """
    rule = RecurringService.pause_rule(
        db=db,
        user_id=current_user.id,
        rule_id=id
    )
    return RecurringExpenseResponse.model_validate(rule)


@router.post(
    "/{id}/resume",
    response_model=RecurringExpenseResponse,
    summary="Resume a paused recurring expense rule"
)
def resume_recurring_rule(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringExpenseResponse:
    """
    Resumes a paused recurring rule.
    """
    rule = RecurringService.resume_rule(
        db=db,
        user_id=current_user.id,
        rule_id=id
    )
    return RecurringExpenseResponse.model_validate(rule)


@router.post(
    "/{id}/cancel",
    response_model=RecurringExpenseResponse,
    summary="Cancel a recurring expense rule"
)
def cancel_recurring_rule(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringExpenseResponse:
    """
    Cancels a recurring rule. Previously generated expenses are retained.
    """
    rule = RecurringService.cancel_rule(
        db=db,
        user_id=current_user.id,
        rule_id=id
    )
    return RecurringExpenseResponse.model_validate(rule)


@router.delete(
    "/{id}",
    response_model=RecurringExpenseResponse,
    summary="Delete / Cancel a recurring expense rule"
)
def delete_recurring_rule(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> RecurringExpenseResponse:
    """
    Deletes or cancels a recurring rule.
    """
    rule = RecurringService.cancel_rule(
        db=db,
        user_id=current_user.id,
        rule_id=id
    )
    return RecurringExpenseResponse.model_validate(rule)


@router.get(
    "/{id}/history",
    response_model=List[ExpenseResponse],
    summary="View expense history generated by this recurring rule"
)
def get_recurring_rule_history(
    id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[ExpenseResponse]:
    """
    Lists all expenses generated by this specific recurring rule.
    """
    expenses = RecurringService.get_rule_history(
        db=db,
        user_id=current_user.id,
        rule_id=id
    )
    return [ExpenseResponse.model_validate(e) for e in expenses]
