import json
from datetime import date
from unittest.mock import AsyncMock
from uuid import uuid4

import httpx
import openai
import pytest

from app.core.config import settings
from app.schemas.measurement import BodyMeasurementProgress
from app.schemas.recommendation import AIGeneratedContent
from app.schemas.weekly_summary import (
    WeeklyDataQuality,
    WeeklyNutrition,
    WeeklySummaryPeriod,
    WeeklySummaryResponse,
    WeeklySummaryUser,
)
from app.schemas.workout_log import WorkoutLogSummary
from app.services.ai_provider import (
    AIProviderError,
    AIProviderNotConfiguredError,
    AIProviderTimeoutError,
    AzureOpenAIProvider,
)


def _summary() -> WeeklySummaryResponse:
    return WeeklySummaryResponse(
        user=WeeklySummaryUser(id=uuid4(), name="Test User", goal="body recomposition"),
        period=WeeklySummaryPeriod(week_start=date(2026, 7, 1), week_end=date(2026, 7, 7)),
        workouts=WorkoutLogSummary(
            total_logs=1, total_sets=4, total_reps=32, unique_exercises=1, workout_days=1
        ),
        nutrition=WeeklyNutrition(
            days_logged=3,
            avg_calories=1850,
            avg_protein=105.5,
            avg_carbs=210,
            avg_fats=55,
            total_calories=5550,
            total_protein=316.5,
            total_carbs=630,
            total_fats=165,
        ),
        measurements=BodyMeasurementProgress(measurements_count=1),
        data_quality=WeeklyDataQuality(
            has_workout_data=True,
            has_nutrition_data=True,
            has_measurement_data=True,
            nutrition_days_logged=3,
            measurement_entries=1,
            is_ready_for_ai_recommendation=True,
            missing_data=[],
        ),
    )


def _fake_client(create_mock: AsyncMock) -> AsyncMock:
    client = AsyncMock()
    client.chat.completions.create = create_mock
    return client


def _chat_response(content: str) -> AsyncMock:
    response = AsyncMock()
    response.choices = [AsyncMock(message=AsyncMock(content=content))]
    return response


async def test_generate_calls_client_with_deployment_and_json_response_format() -> None:
    valid_payload = {
        "summary": "Good week overall.",
        "insights": ["Consistent training."],
        "recommendation": "Keep it up.",
        "safety_notes": "This recommendation is for general fitness habit tracking only.",
    }
    create_mock = AsyncMock(return_value=_chat_response(json.dumps(valid_payload)))
    provider = AzureOpenAIProvider(client=_fake_client(create_mock))

    raw = await provider.generate(_summary())

    assert json.loads(raw) == valid_payload
    AIGeneratedContent.model_validate(json.loads(raw))

    _, kwargs = create_mock.call_args
    assert kwargs["model"] == settings.azure_openai_deployment
    assert kwargs["response_format"] == {"type": "json_object"}
    assert kwargs["messages"][0]["role"] == "user"
    assert "Weekly data (JSON):" in kwargs["messages"][0]["content"]


async def test_generate_raises_not_configured_error_without_credentials(monkeypatch) -> None:
    monkeypatch.setattr(settings, "azure_openai_endpoint", "")
    monkeypatch.setattr(settings, "azure_openai_api_key", "")
    monkeypatch.setattr(settings, "azure_openai_deployment", "")
    monkeypatch.setattr(settings, "azure_openai_api_version", "")
    provider = AzureOpenAIProvider()

    with pytest.raises(AIProviderNotConfiguredError):
        await provider.generate(_summary())


async def test_generate_raises_timeout_error_on_api_timeout() -> None:
    request = httpx.Request("POST", "https://example.openai.azure.com")
    create_mock = AsyncMock(side_effect=openai.APITimeoutError(request=request))
    provider = AzureOpenAIProvider(client=_fake_client(create_mock))

    with pytest.raises(AIProviderTimeoutError):
        await provider.generate(_summary())


async def test_generate_raises_provider_error_on_generic_api_error() -> None:
    request = httpx.Request("POST", "https://example.openai.azure.com")
    create_mock = AsyncMock(
        side_effect=openai.APIConnectionError(message="connection reset", request=request)
    )
    provider = AzureOpenAIProvider(client=_fake_client(create_mock))

    with pytest.raises(AIProviderError):
        await provider.generate(_summary())


async def test_generate_raises_provider_error_on_empty_content() -> None:
    create_mock = AsyncMock(return_value=_chat_response(None))
    provider = AzureOpenAIProvider(client=_fake_client(create_mock))

    with pytest.raises(AIProviderError):
        await provider.generate(_summary())
