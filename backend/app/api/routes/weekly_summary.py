from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.weekly_summary import WeeklySummaryResponse
from app.services import weekly_summary_service

router = APIRouter(prefix="/weekly-summary", tags=["weekly-summary"])


@router.get("", response_model=WeeklySummaryResponse)
async def get_weekly_summary(
    week_start: date,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> WeeklySummaryResponse:
    return await weekly_summary_service.get_weekly_summary(session, current_user, week_start)
