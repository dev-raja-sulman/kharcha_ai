from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.saving_goal import SavingContribution, SavingGoal
from app.models.user import User
from app.schemas.saving_goal import (
    ContributionCreate,
    ContributionResponse,
    SavingGoalCreate,
    SavingGoalListResponse,
    SavingGoalResponse,
    SavingGoalUpdate,
)
from app.services.saving_service import SavingService

router = APIRouter(prefix="/saving-goals", tags=["Saving Goals"])


def _to_goal_response(goal: SavingGoal) -> SavingGoalResponse:
    return SavingGoalResponse(
        id=goal.id,
        user_id=goal.user_id,
        title=goal.title,
        description=goal.description,
        target_amount=goal.target_amount,
        current_amount=goal.current_amount,
        start_date=goal.start_date,
        target_date=goal.target_date,
        status=goal.status,
        remaining_amount=goal.remaining_amount,
        progress_percentage=goal.progress_percentage,
        created_at=goal.created_at,
        updated_at=goal.updated_at
    )


@router.post(
    "",
    response_model=SavingGoalResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new savings goal"
)
def create_saving_goal(
    goal_in: SavingGoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SavingGoalResponse:
    goal = SavingService.create_goal(
        db=db,
        user_id=current_user.id,
        goal_in=goal_in
    )
    return _to_goal_response(goal)


@router.get(
    "",
    response_model=SavingGoalListResponse,
    status_code=status.HTTP_200_OK,
    summary="List all saving goals for authenticated user"
)
def list_saving_goals(
    status_filter: Optional[str] = Query(None, description="Filter by status: in_progress | completed | cancelled"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SavingGoalListResponse:
    goals, total_saved = SavingService.get_goals(
        db=db,
        user_id=current_user.id,
        status_filter=status_filter
    )
    return SavingGoalListResponse(
        total=len(goals),
        total_savings=total_saved,
        items=[_to_goal_response(g) for g in goals]
    )


@router.get(
    "/{goal_id}",
    response_model=SavingGoalResponse,
    status_code=status.HTTP_200_OK,
    summary="Get single saving goal details"
)
def get_saving_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SavingGoalResponse:
    goal = SavingService.get_goal_by_id(
        db=db,
        user_id=current_user.id,
        goal_id=goal_id
    )
    return _to_goal_response(goal)


@router.put(
    "/{goal_id}",
    response_model=SavingGoalResponse,
    status_code=status.HTTP_200_OK,
    summary="Update saving goal details"
)
def update_saving_goal(
    goal_id: int,
    goal_in: SavingGoalUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> SavingGoalResponse:
    goal = SavingService.update_goal(
        db=db,
        user_id=current_user.id,
        goal_id=goal_id,
        goal_in=goal_in
    )
    return _to_goal_response(goal)


@router.delete(
    "/{goal_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a saving goal"
)
def delete_saving_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> None:
    SavingService.delete_goal(
        db=db,
        user_id=current_user.id,
        goal_id=goal_id
    )


@router.post(
    "/{goal_id}/contributions",
    response_model=ContributionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add a savings contribution to a goal"
)
def add_contribution(
    goal_id: int,
    contrib_in: ContributionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> ContributionResponse:
    contrib = SavingService.add_contribution(
        db=db,
        user_id=current_user.id,
        goal_id=goal_id,
        contrib_in=contrib_in
    )
    return ContributionResponse.model_validate(contrib)


@router.get(
    "/{goal_id}/contributions",
    response_model=List[ContributionResponse],
    status_code=status.HTTP_200_OK,
    summary="List contributions history for a goal"
)
def list_contributions(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[ContributionResponse]:
    contributions = SavingService.get_contributions(
        db=db,
        user_id=current_user.id,
        goal_id=goal_id
    )
    return [ContributionResponse.model_validate(c) for c in contributions]
