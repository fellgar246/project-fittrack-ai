from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.workout_log import WorkoutLogCreate, WorkoutLogRead, WorkoutLogSummary
from app.services import workout_log_service

router = APIRouter(prefix="/workout-logs", tags=["workout-logs"])


@router.post("", response_model=WorkoutLogRead, status_code=201)
async def create_workout_log(
    data: WorkoutLogCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WorkoutLogRead:
    log = await workout_log_service.create_workout_log(session, current_user.id, data)
    if log is None:
        raise HTTPException(status_code=404, detail="Exercise not found")
    return workout_log_service.build_read(log)


@router.get("", response_model=list[WorkoutLogRead])
async def list_workout_logs(
    date_from: date | None = None,
    date_to: date | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[WorkoutLogRead]:
    logs = await workout_log_service.list_workout_logs(
        session, current_user.id, date_from, date_to
    )
    return [workout_log_service.build_read(log) for log in logs]


@router.get("/summary", response_model=WorkoutLogSummary)
async def get_workout_logs_summary(
    date_from: date | None = None,
    date_to: date | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WorkoutLogSummary:
    return await workout_log_service.get_summary(session, current_user.id, date_from, date_to)
