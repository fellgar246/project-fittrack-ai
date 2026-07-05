from datetime import date
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class WeeklyRecommendationRequest(BaseModel):
    """Client input for generating a weekly recommendation.

    Only ``week_start`` is accepted. ``week_end`` is derived on the backend and
    ``user_id`` always comes from the authenticated user, never from the client.
    """

    week_start: date


class AIGeneratedContent(BaseModel):
    """Schema used to validate the raw JSON returned by an AI provider.

    Keeping this separate from the persisted response lets us fail in a
    controlled way if the provider returns malformed or unexpected output.
    """

    summary: str = Field(min_length=1)
    insights: list[str] = Field(default_factory=list)
    recommendation: str = Field(min_length=1)
    safety_notes: str | None = None


class RecommendationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    week_start: date
    week_end: date
    summary: str
    insights: list[str]
    recommendation: str
    safety_notes: str | None
