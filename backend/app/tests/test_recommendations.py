from httpx import AsyncClient

from app.main import app
from app.services.ai_provider import (
    AIProvider,
    AIProviderError,
    AIProviderNotConfiguredError,
    AIProviderTimeoutError,
    get_ai_provider,
)

WEEK_START = "2026-07-01"

PLAN_PAYLOAD = {
    "name": "4-Day Body Recomposition Plan",
    "goal": "body recomposition",
    "active": True,
    "days": [
        {
            "day_of_week": 1,
            "title": "Upper Body",
            "exercises": [
                {
                    "name": "Pull-ups",
                    "muscle_group": "back",
                    "target_sets": 4,
                    "target_reps": "6-8",
                },
            ],
        },
    ],
}


async def _register_and_login(client: AsyncClient, email: str) -> str:
    await client.post(
        "/auth/register",
        json={
            "email": email,
            "name": "Test User",
            "password": "StrongPassword123",
            "goal": "body recomposition",
        },
    )
    response = await client.post(
        "/auth/login", json={"email": email, "password": "StrongPassword123"}
    )
    return response.json()["access_token"]


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def _create_exercise(client: AsyncClient, token: str) -> str:
    response = await client.post(
        "/workout-plans", json=PLAN_PAYLOAD, headers=_auth_headers(token)
    )
    plan_id = response.json()["id"]
    detail = await client.get(f"/workout-plans/{plan_id}", headers=_auth_headers(token))
    return detail.json()["days"][0]["exercises"][0]["id"]


def _workout_log_payload(exercise_id: str, performed_at: str = "2026-07-01T08:00:00") -> dict:
    return {
        "exercise_id": exercise_id,
        "performed_at": performed_at,
        "sets": 4,
        "reps": 8,
        "weight": 12.5,
        "notes": "Felt strong.",
    }


def _nutrition_log_payload(log_date: str) -> dict:
    return {
        "date": log_date,
        "calories": 1850,
        "protein": 105.5,
        "carbs": 210,
        "fats": 55,
        "notes": "Good protein intake.",
    }


def _measurement_payload(measurement_date: str, weight: float = 70.2) -> dict:
    return {
        "date": measurement_date,
        "weight": weight,
        "waist": 82.5,
        "body_fat_estimate": 24.5,
        "notes": "Morning measurement.",
    }


async def _seed_ready_week(client: AsyncClient, token: str) -> str:
    """Create the minimum data to satisfy is_ready_for_ai_recommendation.

    Returns the created exercise id so callers can seed additional weeks.
    """
    exercise_id = await _create_exercise(client, token)
    await client.post(
        "/workout-logs",
        json=_workout_log_payload(exercise_id, "2026-07-01T08:00:00"),
        headers=_auth_headers(token),
    )
    for day in ("2026-07-01", "2026-07-02", "2026-07-03"):
        await client.post(
            "/nutrition-logs", json=_nutrition_log_payload(day), headers=_auth_headers(token)
        )
    await client.post(
        "/measurements", json=_measurement_payload("2026-07-01"), headers=_auth_headers(token)
    )
    return exercise_id


async def test_generate_recommendation_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.post("/recommendations/weekly", json={"week_start": WEEK_START})

    assert response.status_code == 401


async def test_generate_recommendation_with_invalid_payload_returns_422(
    client: AsyncClient,
) -> None:
    token = await _register_and_login(client, "owner@example.com")

    missing = await client.post(
        "/recommendations/weekly", json={}, headers=_auth_headers(token)
    )
    bad_date = await client.post(
        "/recommendations/weekly",
        json={"week_start": "not-a-date"},
        headers=_auth_headers(token),
    )

    assert missing.status_code == 422
    assert bad_date.status_code == 422


async def test_generate_recommendation_without_enough_data_returns_422(
    client: AsyncClient,
) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.post(
        "/recommendations/weekly",
        json={"week_start": WEEK_START},
        headers=_auth_headers(token),
    )

    assert response.status_code == 422
    assert "missing_data" in response.json()["detail"]


async def test_generate_recommendation_with_enough_data_returns_201(
    client: AsyncClient,
) -> None:
    token = await _register_and_login(client, "owner@example.com")
    await _seed_ready_week(client, token)

    response = await client.post(
        "/recommendations/weekly",
        json={"week_start": WEEK_START},
        headers=_auth_headers(token),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["week_start"] == "2026-07-01"
    assert body["week_end"] == "2026-07-07"
    assert body["summary"]
    assert isinstance(body["insights"], list)
    assert body["recommendation"]
    assert "does not replace medical advice" in body["safety_notes"]


async def test_generated_recommendation_is_persisted(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    await _seed_ready_week(client, token)

    created = await client.post(
        "/recommendations/weekly",
        json={"week_start": WEEK_START},
        headers=_auth_headers(token),
    )
    created_id = created.json()["id"]

    latest = await client.get("/recommendations/latest", headers=_auth_headers(token))

    assert latest.status_code == 200
    assert latest.json()["id"] == created_id


async def test_duplicate_recommendation_for_same_week_returns_409(
    client: AsyncClient,
) -> None:
    token = await _register_and_login(client, "owner@example.com")
    await _seed_ready_week(client, token)

    first = await client.post(
        "/recommendations/weekly",
        json={"week_start": WEEK_START},
        headers=_auth_headers(token),
    )
    second = await client.post(
        "/recommendations/weekly",
        json={"week_start": WEEK_START},
        headers=_auth_headers(token),
    )

    assert first.status_code == 201
    assert second.status_code == 409


async def test_latest_returns_most_recent_recommendation(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    exercise_id = await _seed_ready_week(client, token)

    await client.post(
        "/recommendations/weekly",
        json={"week_start": "2026-07-01"},
        headers=_auth_headers(token),
    )

    # Seed a second, later week and generate its recommendation; it should win.
    await client.post(
        "/workout-logs",
        json=_workout_log_payload(exercise_id, "2026-07-08T08:00:00"),
        headers=_auth_headers(token),
    )
    for day in ("2026-07-08", "2026-07-09", "2026-07-10"):
        await client.post(
            "/nutrition-logs", json=_nutrition_log_payload(day), headers=_auth_headers(token)
        )
    await client.post(
        "/measurements", json=_measurement_payload("2026-07-08"), headers=_auth_headers(token)
    )
    await client.post(
        "/recommendations/weekly",
        json={"week_start": "2026-07-08"},
        headers=_auth_headers(token),
    )

    latest = await client.get("/recommendations/latest", headers=_auth_headers(token))

    assert latest.status_code == 200
    assert latest.json()["week_start"] == "2026-07-08"


async def test_latest_without_recommendations_returns_404(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.get("/recommendations/latest", headers=_auth_headers(token))

    assert response.status_code == 404


async def test_user_cannot_see_other_users_recommendation(client: AsyncClient) -> None:
    owner_token = await _register_and_login(client, "owner@example.com")
    other_token = await _register_and_login(client, "other@example.com")
    await _seed_ready_week(client, owner_token)

    await client.post(
        "/recommendations/weekly",
        json={"week_start": WEEK_START},
        headers=_auth_headers(owner_token),
    )

    other_latest = await client.get(
        "/recommendations/latest", headers=_auth_headers(other_token)
    )

    assert other_latest.status_code == 404


async def test_invalid_ai_response_returns_502(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    await _seed_ready_week(client, token)

    class BrokenProvider(AIProvider):
        async def generate(self, summary) -> str:  # noqa: ANN001
            return "this is not valid json"

    app.dependency_overrides[get_ai_provider] = lambda: BrokenProvider()
    try:
        response = await client.post(
            "/recommendations/weekly",
            json={"week_start": WEEK_START},
            headers=_auth_headers(token),
        )
    finally:
        app.dependency_overrides.pop(get_ai_provider, None)

    assert response.status_code == 502


async def test_ai_provider_not_configured_returns_503(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    await _seed_ready_week(client, token)

    class NotConfiguredProvider(AIProvider):
        async def generate(self, summary) -> str:  # noqa: ANN001
            raise AIProviderNotConfiguredError("missing config")

    app.dependency_overrides[get_ai_provider] = lambda: NotConfiguredProvider()
    try:
        response = await client.post(
            "/recommendations/weekly",
            json={"week_start": WEEK_START},
            headers=_auth_headers(token),
        )
    finally:
        app.dependency_overrides.pop(get_ai_provider, None)

    assert response.status_code == 503


async def test_ai_provider_timeout_returns_503(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    await _seed_ready_week(client, token)

    class TimeoutProvider(AIProvider):
        async def generate(self, summary) -> str:  # noqa: ANN001
            raise AIProviderTimeoutError("timed out")

    app.dependency_overrides[get_ai_provider] = lambda: TimeoutProvider()
    try:
        response = await client.post(
            "/recommendations/weekly",
            json={"week_start": WEEK_START},
            headers=_auth_headers(token),
        )
    finally:
        app.dependency_overrides.pop(get_ai_provider, None)

    assert response.status_code == 503


async def test_ai_provider_generic_error_returns_502(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    await _seed_ready_week(client, token)

    class FailingProvider(AIProvider):
        async def generate(self, summary) -> str:  # noqa: ANN001
            raise AIProviderError("request failed")

    app.dependency_overrides[get_ai_provider] = lambda: FailingProvider()
    try:
        response = await client.post(
            "/recommendations/weekly",
            json={"week_start": WEEK_START},
            headers=_auth_headers(token),
        )
    finally:
        app.dependency_overrides.pop(get_ai_provider, None)

    assert response.status_code == 502
