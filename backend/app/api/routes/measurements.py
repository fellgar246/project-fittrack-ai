from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.measurement import (
    BodyMeasurementCreate,
    BodyMeasurementProgress,
    BodyMeasurementRead,
)
from app.services import measurement_service

router = APIRouter(prefix="/measurements", tags=["measurements"])


@router.post("", response_model=BodyMeasurementRead, status_code=201)
async def create_measurement(
    data: BodyMeasurementCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> BodyMeasurementRead:
    measurement = await measurement_service.create_measurement(
        session, current_user.id, data
    )
    if measurement is None:
        raise HTTPException(
            status_code=409, detail="Body measurement already exists for this date"
        )
    return measurement


@router.get("", response_model=list[BodyMeasurementRead])
async def list_measurements(
    date_from: date | None = None,
    date_to: date | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[BodyMeasurementRead]:
    return await measurement_service.list_measurements(
        session, current_user.id, date_from, date_to
    )


@router.get("/progress", response_model=BodyMeasurementProgress)
async def get_measurements_progress(
    date_from: date | None = None,
    date_to: date | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> BodyMeasurementProgress:
    return await measurement_service.get_progress(
        session, current_user.id, date_from, date_to
    )
