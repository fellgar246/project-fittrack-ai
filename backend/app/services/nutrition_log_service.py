from datetime import date
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.nutrition import NutritionLog
from app.schemas.nutrition_log import NutritionLogCreate, NutritionLogSummary


async def _log_exists_for_date(session: AsyncSession, user_id: UUID, log_date: date) -> bool:
    result = await session.execute(
        select(NutritionLog.id).where(
            NutritionLog.user_id == user_id, NutritionLog.date == log_date
        )
    )
    return result.scalar_one_or_none() is not None


async def create_nutrition_log(
    session: AsyncSession, user_id: UUID, data: NutritionLogCreate
) -> NutritionLog | None:
    if await _log_exists_for_date(session, user_id, data.date):
        return None

    log = NutritionLog(
        user_id=user_id,
        date=data.date,
        calories=data.calories,
        protein=data.protein,
        carbs=data.carbs,
        fats=data.fats,
        notes=data.notes,
    )
    session.add(log)
    await session.commit()

    result = await session.execute(select(NutritionLog).where(NutritionLog.id == log.id))
    return result.scalar_one()


def _date_range_filters(
    user_id: UUID, date_from: date | None, date_to: date | None
) -> list:
    filters = [NutritionLog.user_id == user_id]
    if date_from is not None:
        filters.append(NutritionLog.date >= date_from)
    if date_to is not None:
        filters.append(NutritionLog.date <= date_to)
    return filters


async def list_nutrition_logs(
    session: AsyncSession, user_id: UUID, date_from: date | None, date_to: date | None
) -> list[NutritionLog]:
    result = await session.execute(
        select(NutritionLog)
        .where(*_date_range_filters(user_id, date_from, date_to))
        .order_by(NutritionLog.date.desc())
    )
    return list(result.scalars().all())


async def get_summary(
    session: AsyncSession, user_id: UUID, date_from: date | None, date_to: date | None
) -> NutritionLogSummary:
    result = await session.execute(
        select(
            func.count(),
            func.coalesce(func.avg(NutritionLog.calories), 0),
            func.coalesce(func.avg(NutritionLog.protein), 0),
            func.coalesce(func.avg(NutritionLog.carbs), 0),
            func.coalesce(func.avg(NutritionLog.fats), 0),
            func.coalesce(func.sum(NutritionLog.calories), 0),
            func.coalesce(func.sum(NutritionLog.protein), 0),
            func.coalesce(func.sum(NutritionLog.carbs), 0),
            func.coalesce(func.sum(NutritionLog.fats), 0),
        ).where(*_date_range_filters(user_id, date_from, date_to))
    )
    (
        days_logged,
        avg_calories,
        avg_protein,
        avg_carbs,
        avg_fats,
        total_calories,
        total_protein,
        total_carbs,
        total_fats,
    ) = result.one()

    return NutritionLogSummary(
        days_logged=days_logged,
        avg_calories=avg_calories,
        avg_protein=avg_protein,
        avg_carbs=avg_carbs,
        avg_fats=avg_fats,
        total_calories=total_calories,
        total_protein=total_protein,
        total_carbs=total_carbs,
        total_fats=total_fats,
    )
