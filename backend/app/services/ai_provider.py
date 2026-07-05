"""AI provider abstraction for weekly fitness recommendations.

This module isolates the AI integration point behind a small interface so the
rest of the app never talks to a concrete model directly. The default provider
is a deterministic fake that requires no network access or credentials, which
keeps local development and tests stable. ``AzureOpenAIProvider`` implements
the real Azure OpenAI integration, selected via ``AI_PROVIDER=azure``.
"""

from __future__ import annotations

import json
from abc import ABC, abstractmethod

import openai
from openai import AsyncAzureOpenAI

from app.core.config import settings
from app.schemas.weekly_summary import WeeklySummaryResponse

# Kept low and deterministic: this feature reports on data the user already
# logged, it does not need creative variation between requests.
_TEMPERATURE = 0.4

SAFETY_NOTES = (
    "This recommendation is for general fitness habit tracking only and does "
    "not replace medical advice."
)

# System-style instructions embedded into the prompt sent to a real model.
# They constrain the AI to safe, general, data-grounded fitness observations.
PROMPT_INSTRUCTIONS = (
    "You are a supportive fitness habit assistant for the FitTrack AI app. "
    "Use ONLY the weekly data provided below. Do not invent information. "
    "Do not give medical advice, diagnoses, or clinical guidance. "
    "Do not recommend extreme calorie changes, supplements, or medication. "
    "Do not make negative comments about the user's body or promise weight loss. "
    "Keep the tone clear, practical, and motivating, focused on general habits "
    "of training, nutrition, and consistency. If there is little information, "
    "say so with caution. "
    "Respond ONLY with a JSON object with exactly these keys: "
    '"summary" (string), "insights" (array of strings), '
    '"recommendation" (string), "safety_notes" (string).'
)


def build_prompt(summary: WeeklySummaryResponse) -> str:
    """Build a safe, structured prompt from the consolidated weekly summary."""
    data = summary.model_dump(mode="json")
    return (
        f"{PROMPT_INSTRUCTIONS}\n\n"
        f"Weekly data (JSON):\n{json.dumps(data, ensure_ascii=False)}"
    )


class AIProviderError(Exception):
    """Raised when the AI provider fails in a way callers should treat as a
    controlled upstream failure (mapped to a 502 by the route)."""


class AIProviderNotConfiguredError(AIProviderError):
    """Raised when AI_PROVIDER=azure is selected without full configuration."""


class AIProviderTimeoutError(AIProviderError):
    """Raised when the AI provider does not respond within the configured timeout."""


class AIProvider(ABC):
    """Generates a raw JSON string from a consolidated weekly summary."""

    @abstractmethod
    async def generate(self, summary: WeeklySummaryResponse) -> str:
        """Return a JSON string with summary/insights/recommendation/safety_notes."""


class FakeAIProvider(AIProvider):
    """Deterministic provider built from local rules over the weekly summary.

    It produces realistic, data-grounded output without any external call,
    which makes end-to-end flows and tests fully reproducible.
    """

    async def generate(self, summary: WeeklySummaryResponse) -> str:
        workouts = summary.workouts
        nutrition = summary.nutrition
        measurements = summary.measurements

        summary_text = (
            f"Completaste {workouts.total_logs} registros de entrenamiento en "
            f"{workouts.workout_days} día(s) y registraste nutrición "
            f"{nutrition.days_logged} día(s)."
        )
        if measurements.weight_change is not None:
            direction = "bajó" if measurements.weight_change < 0 else "subió"
            if measurements.weight_change == 0:
                direction = "se mantuvo"
            summary_text += (
                f" Tu peso {direction} "
                f"{abs(measurements.weight_change):.1f} kg en el periodo."
            )

        insights: list[str] = []
        if workouts.total_logs > 0:
            insights.append(
                "Tu consistencia de entrenamiento fue "
                + ("buena" if workouts.workout_days >= 3 else "moderada")
                + " durante la semana."
            )
        if nutrition.days_logged >= 3:
            insights.append(
                "La proteína estuvo registrada durante suficientes días para "
                "detectar una tendencia."
            )
        if measurements.waist_change is not None and measurements.waist_change < 0:
            insights.append("Tu cintura mostró una ligera reducción.")
        if not insights:
            insights.append(
                "Los datos disponibles son limitados; conviene registrar con "
                "más constancia para obtener mejores observaciones."
            )

        recommendation = (
            "Mantén tus calorías similares durante una semana más, prioriza "
            "llegar a tu proteína diaria y conserva la estructura actual de "
            "entrenamiento."
        )

        content = {
            "summary": summary_text,
            "insights": insights,
            "recommendation": recommendation,
            "safety_notes": SAFETY_NOTES,
        }
        return json.dumps(content, ensure_ascii=False)


class AzureOpenAIProvider(AIProvider):
    """Real Azure OpenAI provider.

    Configuration is validated lazily inside ``generate`` (not in
    ``__init__``) so that a misconfigured or unreachable Azure deployment
    surfaces as a controlled error handled by the route, rather than an
    unhandled exception raised while resolving the ``get_ai_provider``
    dependency.
    """

    def __init__(self, client: AsyncAzureOpenAI | None = None) -> None:
        # Tests inject a fake client here to exercise `generate` without any
        # network access or credentials.
        self._client = client

    def _create_client(self) -> AsyncAzureOpenAI:
        missing = [
            name
            for name, value in {
                "AZURE_OPENAI_ENDPOINT": settings.azure_openai_endpoint,
                "AZURE_OPENAI_API_KEY": settings.azure_openai_api_key,
                "AZURE_OPENAI_DEPLOYMENT": settings.azure_openai_deployment,
                "AZURE_OPENAI_API_VERSION": settings.azure_openai_api_version,
            }.items()
            if not value
        ]
        if missing:
            raise AIProviderNotConfiguredError(
                "Azure OpenAI provider is not configured. Missing: "
                + ", ".join(missing)
            )
        return AsyncAzureOpenAI(
            azure_endpoint=settings.azure_openai_endpoint,
            api_key=settings.azure_openai_api_key,
            api_version=settings.azure_openai_api_version,
            timeout=settings.azure_openai_timeout_seconds,
            max_retries=settings.azure_openai_max_retries,
        )

    async def generate(self, summary: WeeklySummaryResponse) -> str:
        prompt = build_prompt(summary)
        client = self._client or self._create_client()

        try:
            response = await client.chat.completions.create(
                model=settings.azure_openai_deployment,
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"},
                temperature=_TEMPERATURE,
            )
        except openai.APITimeoutError as exc:
            raise AIProviderTimeoutError("AI provider timed out") from exc
        except openai.OpenAIError as exc:
            # Never surface SDK internals (which may include request details)
            # to the client; log context without secrets if logging is added.
            raise AIProviderError("AI provider request failed") from exc

        content = response.choices[0].message.content
        if not content:
            raise AIProviderError("AI provider returned empty content")
        return content


def get_ai_provider() -> AIProvider:
    """FastAPI dependency that selects the provider from configuration.

    Exposed as a dependency so tests can override it with a stub without
    touching global state.
    """
    if settings.ai_provider == "azure":
        return AzureOpenAIProvider()
    return FakeAIProvider()
