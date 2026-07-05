from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.recommendation import RecommendationRead, WeeklyRecommendationRequest
from app.services import recommendation_service
from app.services.ai_provider import (
    AIProvider,
    AIProviderError,
    AIProviderNotConfiguredError,
    AIProviderTimeoutError,
    get_ai_provider,
)

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.post("/weekly", response_model=RecommendationRead, status_code=201)
async def generate_weekly_recommendation(
    data: WeeklyRecommendationRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    provider: AIProvider = Depends(get_ai_provider),
) -> RecommendationRead:
    try:
        return await recommendation_service.generate_weekly_recommendation(
            session, current_user, provider, data.week_start
        )
    except recommendation_service.NotEnoughDataError as exc:
        raise HTTPException(
            status_code=422,
            detail={
                "message": "Not enough weekly data to generate recommendation",
                "missing_data": exc.missing_data,
            },
        ) from exc
    except recommendation_service.RecommendationAlreadyExistsError as exc:
        raise HTTPException(
            status_code=409, detail="Recommendation already exists for this week"
        ) from exc
    except AIProviderNotConfiguredError as exc:
        raise HTTPException(
            status_code=503, detail="AI provider is not configured"
        ) from exc
    except AIProviderTimeoutError as exc:
        raise HTTPException(status_code=503, detail="AI provider timeout") from exc
    except AIProviderError as exc:
        raise HTTPException(status_code=502, detail="AI provider failed") from exc
    except recommendation_service.InvalidAIResponseError as exc:
        raise HTTPException(
            status_code=502, detail="AI provider returned an invalid response"
        ) from exc


@router.get("/latest", response_model=RecommendationRead)
async def get_latest_recommendation(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> RecommendationRead:
    recommendation = await recommendation_service.get_latest_recommendation(
        session, current_user.id
    )
    if recommendation is None:
        raise HTTPException(status_code=404, detail="Recommendation not found")
    return recommendation
