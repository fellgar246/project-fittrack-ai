from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.nutrition_log import NutritionLogCreate, NutritionLogRead, NutritionLogSummary
from app.services import nutrition_log_service

router = APIRouter(prefix="/nutrition-logs", tags=["nutrition-logs"])


@router.post("", response_model=NutritionLogRead, status_code=201)
async def create_nutrition_log(
    data: NutritionLogCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> NutritionLogRead:
    log = await nutrition_log_service.create_nutrition_log(session, current_user.id, data)
    if log is None:
        raise HTTPException(
            status_code=409, detail="Nutrition log already exists for this date"
        )
    return log


@router.get("", response_model=list[NutritionLogRead])
async def list_nutrition_logs(
    date_from: date | None = None,
    date_to: date | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[NutritionLogRead]:
    return await nutrition_log_service.list_nutrition_logs(
        session, current_user.id, date_from, date_to
    )


@router.get("/summary", response_model=NutritionLogSummary)
async def get_nutrition_logs_summary(
    date_from: date | None = None,
    date_to: date | None = None,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> NutritionLogSummary:
    return await nutrition_log_service.get_summary(session, current_user.id, date_from, date_to)
