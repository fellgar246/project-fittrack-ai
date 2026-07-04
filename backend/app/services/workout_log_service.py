from datetime import date
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.workout import Exercise, WorkoutDay, WorkoutLog, WorkoutPlan
from app.schemas.workout_log import WorkoutLogCreate, WorkoutLogRead, WorkoutLogSummary


def build_read(log: WorkoutLog) -> WorkoutLogRead:
    return WorkoutLogRead(
        id=log.id,
        exercise_id=log.exercise_id,
        exercise_name=log.exercise.name,
        performed_at=log.performed_at,
        sets=log.sets,
        reps=log.reps,
        weight=log.weight,
        notes=log.notes,
    )


async def _exercise_belongs_to_user(
    session: AsyncSession, user_id: UUID, exercise_id: UUID
) -> bool:
    result = await session.execute(
        select(Exercise.id)
        .join(WorkoutDay, Exercise.workout_day_id == WorkoutDay.id)
        .join(WorkoutPlan, WorkoutDay.plan_id == WorkoutPlan.id)
        .where(Exercise.id == exercise_id, WorkoutPlan.user_id == user_id)
    )
    return result.scalar_one_or_none() is not None


async def create_workout_log(
    session: AsyncSession, user_id: UUID, data: WorkoutLogCreate
) -> WorkoutLog | None:
    if not await _exercise_belongs_to_user(session, user_id, data.exercise_id):
        return None

    log = WorkoutLog(
        user_id=user_id,
        exercise_id=data.exercise_id,
        performed_at=data.performed_at,
        sets=data.sets,
        reps=data.reps,
        weight=data.weight,
        notes=data.notes,
    )
    session.add(log)
    await session.commit()

    result = await session.execute(select(WorkoutLog).where(WorkoutLog.id == log.id))
    return result.scalar_one()


def _date_range_filters(
    user_id: UUID, date_from: date | None, date_to: date | None
) -> list:
    filters = [WorkoutLog.user_id == user_id]
    if date_from is not None:
        filters.append(func.date(WorkoutLog.performed_at) >= date_from)
    if date_to is not None:
        filters.append(func.date(WorkoutLog.performed_at) <= date_to)
    return filters


async def list_workout_logs(
    session: AsyncSession, user_id: UUID, date_from: date | None, date_to: date | None
) -> list[WorkoutLog]:
    result = await session.execute(
        select(WorkoutLog)
        .where(*_date_range_filters(user_id, date_from, date_to))
        .order_by(WorkoutLog.performed_at.desc())
    )
    return list(result.scalars().all())


async def get_summary(
    session: AsyncSession, user_id: UUID, date_from: date | None, date_to: date | None
) -> WorkoutLogSummary:
    result = await session.execute(
        select(
            func.count(),
            func.coalesce(func.sum(WorkoutLog.sets), 0),
            func.coalesce(func.sum(WorkoutLog.reps), 0),
            func.count(func.distinct(WorkoutLog.exercise_id)),
            func.count(func.distinct(func.date(WorkoutLog.performed_at))),
        ).where(*_date_range_filters(user_id, date_from, date_to))
    )
    total_logs, total_sets, total_reps, unique_exercises, workout_days = result.one()

    return WorkoutLogSummary(
        total_logs=total_logs,
        total_sets=total_sets,
        total_reps=total_reps,
        unique_exercises=unique_exercises,
        workout_days=workout_days,
    )
