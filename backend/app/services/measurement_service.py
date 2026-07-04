from datetime import date
from decimal import Decimal
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.measurement import BodyMeasurement
from app.schemas.measurement import BodyMeasurementCreate, BodyMeasurementProgress


async def _measurement_exists_for_date(
    session: AsyncSession, user_id: UUID, measurement_date: date
) -> bool:
    result = await session.execute(
        select(BodyMeasurement.id).where(
            BodyMeasurement.user_id == user_id, BodyMeasurement.date == measurement_date
        )
    )
    return result.scalar_one_or_none() is not None


async def create_measurement(
    session: AsyncSession, user_id: UUID, data: BodyMeasurementCreate
) -> BodyMeasurement | None:
    if await _measurement_exists_for_date(session, user_id, data.date):
        return None

    measurement = BodyMeasurement(
        user_id=user_id,
        date=data.date,
        weight=data.weight,
        waist=data.waist,
        body_fat_estimate=data.body_fat_estimate,
        notes=data.notes,
    )
    session.add(measurement)
    await session.commit()

    result = await session.execute(
        select(BodyMeasurement).where(BodyMeasurement.id == measurement.id)
    )
    return result.scalar_one()


def _date_range_filters(
    user_id: UUID, date_from: date | None, date_to: date | None
) -> list:
    filters = [BodyMeasurement.user_id == user_id]
    if date_from is not None:
        filters.append(BodyMeasurement.date >= date_from)
    if date_to is not None:
        filters.append(BodyMeasurement.date <= date_to)
    return filters


async def list_measurements(
    session: AsyncSession, user_id: UUID, date_from: date | None, date_to: date | None
) -> list[BodyMeasurement]:
    result = await session.execute(
        select(BodyMeasurement)
        .where(*_date_range_filters(user_id, date_from, date_to))
        .order_by(BodyMeasurement.date.desc())
    )
    return list(result.scalars().all())


def _to_float(value: Decimal | None) -> float | None:
    return float(value) if value is not None else None


def _change(start: Decimal | None, end: Decimal | None) -> float | None:
    if start is None or end is None:
        return None
    return float(end - start)


async def get_progress(
    session: AsyncSession, user_id: UUID, date_from: date | None, date_to: date | None
) -> BodyMeasurementProgress:
    result = await session.execute(
        select(BodyMeasurement)
        .where(*_date_range_filters(user_id, date_from, date_to))
        .order_by(BodyMeasurement.date.asc())
    )
    measurements = list(result.scalars().all())

    if not measurements:
        return BodyMeasurementProgress(measurements_count=0)

    start = measurements[0]
    end = measurements[-1]

    return BodyMeasurementProgress(
        measurements_count=len(measurements),
        start_date=start.date,
        end_date=end.date,
        start_weight=_to_float(start.weight),
        end_weight=_to_float(end.weight),
        weight_change=_change(start.weight, end.weight),
        start_waist=_to_float(start.waist),
        end_waist=_to_float(end.waist),
        waist_change=_change(start.waist, end.waist),
        start_body_fat_estimate=_to_float(start.body_fat_estimate),
        end_body_fat_estimate=_to_float(end.body_fat_estimate),
        body_fat_change=_change(start.body_fat_estimate, end.body_fat_estimate),
    )
