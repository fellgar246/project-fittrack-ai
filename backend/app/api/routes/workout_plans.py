from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.workout import WorkoutPlanCreate, WorkoutPlanDetail, WorkoutPlanSummary
from app.services import workout_service

router = APIRouter(prefix="/workout-plans", tags=["workout-plans"])


@router.post("", response_model=WorkoutPlanSummary, status_code=201)
async def create_workout_plan(
    data: WorkoutPlanCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WorkoutPlanSummary:
    plan = await workout_service.create_workout_plan(session, current_user.id, data)
    return workout_service.build_summary(plan)


@router.get("", response_model=list[WorkoutPlanSummary])
async def list_workout_plans(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[WorkoutPlanSummary]:
    plans = await workout_service.list_workout_plans(session, current_user.id)
    return [workout_service.build_summary(plan) for plan in plans]


@router.get("/{plan_id}", response_model=WorkoutPlanDetail)
async def get_workout_plan(
    plan_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WorkoutPlanDetail:
    plan = await workout_service.get_workout_plan(session, current_user.id, plan_id)
    if plan is None:
        raise HTTPException(status_code=404, detail="Workout plan not found")
    return plan
