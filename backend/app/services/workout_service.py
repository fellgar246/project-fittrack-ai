from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.workout import Exercise, WorkoutDay, WorkoutPlan
from app.schemas.workout import WorkoutPlanCreate, WorkoutPlanSummary

_PLAN_OPTIONS = (selectinload(WorkoutPlan.days).selectinload(WorkoutDay.exercises),)


def build_summary(plan: WorkoutPlan) -> WorkoutPlanSummary:
    return WorkoutPlanSummary(
        id=plan.id,
        name=plan.name,
        goal=plan.goal,
        active=plan.active,
        days_count=len(plan.days),
        exercises_count=sum(len(day.exercises) for day in plan.days),
    )


async def create_workout_plan(
    session: AsyncSession, user_id: UUID, data: WorkoutPlanCreate
) -> WorkoutPlan:
    plan = WorkoutPlan(
        user_id=user_id,
        name=data.name,
        goal=data.goal,
        active=data.active,
        days=[
            WorkoutDay(
                day_of_week=day.day_of_week,
                title=day.title,
                exercises=[
                    Exercise(
                        name=exercise.name,
                        muscle_group=exercise.muscle_group,
                        target_sets=exercise.target_sets,
                        target_reps=exercise.target_reps,
                    )
                    for exercise in day.exercises
                ],
            )
            for day in data.days
        ],
    )
    session.add(plan)
    await session.commit()

    return await get_workout_plan(session, user_id, plan.id)


async def list_workout_plans(session: AsyncSession, user_id: UUID) -> list[WorkoutPlan]:
    result = await session.execute(
        select(WorkoutPlan).where(WorkoutPlan.user_id == user_id).options(*_PLAN_OPTIONS)
    )
    return list(result.scalars().all())


async def get_workout_plan(
    session: AsyncSession, user_id: UUID, plan_id: UUID
) -> WorkoutPlan | None:
    result = await session.execute(
        select(WorkoutPlan)
        .where(WorkoutPlan.id == plan_id, WorkoutPlan.user_id == user_id)
        .options(*_PLAN_OPTIONS)
    )
    return result.scalar_one_or_none()
