import json
from datetime import date, timedelta
from uuid import UUID

from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ai_recommendation import AIRecommendation
from app.models.user import User
from app.schemas.recommendation import AIGeneratedContent
from app.services import weekly_summary_service
from app.services.ai_provider import SAFETY_NOTES, AIProvider


class NotEnoughDataError(Exception):
    """Raised when the weekly summary is not ready for an AI recommendation."""

    def __init__(self, missing_data: list[str]) -> None:
        self.missing_data = missing_data
        super().__init__("Not enough weekly data to generate recommendation")


class RecommendationAlreadyExistsError(Exception):
    """Raised when a recommendation already exists for the given week."""


class InvalidAIResponseError(Exception):
    """Raised when the AI provider returns malformed or invalid content."""


async def _get_for_week(
    session: AsyncSession, user_id: UUID, week_start: date, week_end: date
) -> AIRecommendation | None:
    result = await session.execute(
        select(AIRecommendation).where(
            AIRecommendation.user_id == user_id,
            AIRecommendation.week_start == week_start,
            AIRecommendation.week_end == week_end,
        )
    )
    return result.scalar_one_or_none()


def _parse_ai_content(raw: str) -> AIGeneratedContent:
    try:
        payload = json.loads(raw)
        return AIGeneratedContent.model_validate(payload)
    except (json.JSONDecodeError, ValidationError, TypeError) as exc:
        raise InvalidAIResponseError(
            "AI provider returned invalid or unparseable content"
        ) from exc


async def generate_weekly_recommendation(
    session: AsyncSession,
    user: User,
    provider: AIProvider,
    week_start: date,
) -> AIRecommendation:
    week_end = week_start + timedelta(days=6)

    summary = await weekly_summary_service.get_weekly_summary(session, user, week_start)
    if not summary.data_quality.is_ready_for_ai_recommendation:
        raise NotEnoughDataError(summary.data_quality.missing_data)

    if await _get_for_week(session, user.id, week_start, week_end) is not None:
        raise RecommendationAlreadyExistsError()

    raw = await provider.generate(summary)
    content = _parse_ai_content(raw)

    recommendation = AIRecommendation(
        user_id=user.id,
        week_start=week_start,
        week_end=week_end,
        summary=content.summary,
        insights=content.insights,
        recommendation=content.recommendation,
        # Always guarantee a safety note, even if the provider omitted one.
        safety_notes=content.safety_notes or SAFETY_NOTES,
    )
    session.add(recommendation)
    await session.commit()

    result = await session.execute(
        select(AIRecommendation).where(AIRecommendation.id == recommendation.id)
    )
    return result.scalar_one()


async def get_latest_recommendation(
    session: AsyncSession, user_id: UUID
) -> AIRecommendation | None:
    result = await session.execute(
        select(AIRecommendation)
        .where(AIRecommendation.user_id == user_id)
        .order_by(
            AIRecommendation.week_start.desc(), AIRecommendation.created_at.desc()
        )
        .limit(1)
    )
    return result.scalar_one_or_none()
