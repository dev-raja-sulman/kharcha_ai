from datetime import date
from decimal import Decimal
import logging
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.saving_goal import SavingContribution, SavingGoal
from app.schemas.saving_goal import ContributionCreate, SavingGoalCreate, SavingGoalUpdate

logger = logging.getLogger(__name__)


class SavingService:
    """
    Business logic for Savings Goals and Contributions in KharchaAI.
    Ensures contributions are treated as fund transfers/allocations into savings,
    maintains atomic balance updates, and enforces user data isolation.
    """

    @classmethod
    def create_goal(cls, db: Session, user_id: int, goal_in: SavingGoalCreate) -> SavingGoal:
        """
        Creates a new saving goal for the authenticated user.
        """
        if goal_in.target_date < goal_in.start_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Target completion date cannot be earlier than the start date."
            )

        new_goal = SavingGoal(
            user_id=user_id,
            title=goal_in.title.strip(),
            description=goal_in.description,
            target_amount=goal_in.target_amount,
            current_amount=Decimal("0.00"),
            start_date=goal_in.start_date,
            target_date=goal_in.target_date,
            status="in_progress"
        )
        db.add(new_goal)
        db.commit()
        db.refresh(new_goal)
        return new_goal

    @classmethod
    def get_goals(
        cls,
        db: Session,
        user_id: int,
        status_filter: Optional[str] = None
    ) -> Tuple[List[SavingGoal], Decimal]:
        """
        Retrieves all goals for user, optionally filtered by status.
        Returns: (goals, total_saved_across_goals)
        """
        query = db.query(SavingGoal).filter(SavingGoal.user_id == user_id)
        if status_filter:
            query = query.filter(SavingGoal.status == status_filter)

        goals = query.order_by(SavingGoal.status.asc(), SavingGoal.target_date.asc()).all()
        total_saved = sum((Decimal(str(g.current_amount)) for g in goals), Decimal("0.00"))
        return goals, total_saved

    @classmethod
    def get_goal_by_id(cls, db: Session, user_id: int, goal_id: int) -> SavingGoal:
        """
        Retrieves a single saving goal ensuring tenant ownership.
        """
        goal = db.query(SavingGoal).filter(
            SavingGoal.id == goal_id,
            SavingGoal.user_id == user_id
        ).first()

        if not goal:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Saving goal with id {goal_id} not found."
            )
        return goal

    @classmethod
    def update_goal(
        cls,
        db: Session,
        user_id: int,
        goal_id: int,
        goal_in: SavingGoalUpdate
    ) -> SavingGoal:
        """
        Updates saving goal parameters.
        """
        goal = cls.get_goal_by_id(db, user_id, goal_id)
        update_data = goal_in.model_dump(exclude_unset=True)

        if "target_amount" in update_data and update_data["target_amount"] is not None:
            new_target = update_data["target_amount"]
            if new_target < goal.current_amount:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Target amount (PKR {new_target}) cannot be lower than already accumulated savings (PKR {goal.current_amount})."
                )

        if "target_date" in update_data and update_data["target_date"] is not None:
            if update_data["target_date"] < goal.start_date:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Target date cannot precede goal start date."
                )

        for key, value in update_data.items():
            setattr(goal, key, value)

        # Check if status should update automatically based on target
        if goal.current_amount >= goal.target_amount and goal.status == "in_progress":
            goal.status = "completed"

        db.commit()
        db.refresh(goal)
        return goal

    @classmethod
    def delete_goal(cls, db: Session, user_id: int, goal_id: int) -> None:
        """
        Deletes a saving goal and its contribution history.
        """
        goal = cls.get_goal_by_id(db, user_id, goal_id)
        db.delete(goal)
        db.commit()

    @classmethod
    def add_contribution(
        cls,
        db: Session,
        user_id: int,
        goal_id: int,
        contrib_in: ContributionCreate
    ) -> SavingContribution:
        """
        Records an atomic savings allocation to the goal.
        Automatically updates goal.current_amount and checks for completion.
        """
        goal = cls.get_goal_by_id(db, user_id, goal_id)

        if goal.status == "cancelled":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot contribute to a cancelled saving goal."
            )

        new_contribution = SavingContribution(
            goal_id=goal_id,
            user_id=user_id,
            amount=contrib_in.amount,
            contribution_date=contrib_in.contribution_date,
            notes=contrib_in.notes
        )

        # Atomically increment current_amount
        goal.current_amount = Decimal(str(goal.current_amount)) + contrib_in.amount

        # Check if target reached
        if goal.current_amount >= Decimal(str(goal.target_amount)) and goal.status == "in_progress":
            goal.status = "completed"

        db.add(new_contribution)
        db.commit()
        db.refresh(new_contribution)
        db.refresh(goal)
        return new_contribution

    @classmethod
    def get_contributions(cls, db: Session, user_id: int, goal_id: int) -> List[SavingContribution]:
        """
        Retrieves contribution history for the specified goal.
        """
        # Validate ownership of goal
        cls.get_goal_by_id(db, user_id, goal_id)

        return db.query(SavingContribution).filter(
            SavingContribution.goal_id == goal_id,
            SavingContribution.user_id == user_id
        ).order_by(SavingContribution.contribution_date.desc(), SavingContribution.id.desc()).all()
