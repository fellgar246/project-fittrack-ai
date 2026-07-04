from httpx import AsyncClient

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


def _workout_log_payload(exercise_id: str, performed_at: str = "2026-07-02T18:30:00") -> dict:
    return {
        "exercise_id": exercise_id,
        "performed_at": performed_at,
        "sets": 4,
        "reps": 8,
        "weight": 12.5,
        "notes": "Felt strong.",
    }


def _nutrition_log_payload(log_date: str = "2026-07-02") -> dict:
    return {
        "date": log_date,
        "calories": 1850,
        "protein": 105.5,
        "carbs": 210,
        "fats": 55,
        "notes": "Good protein intake.",
    }


def _measurement_payload(measurement_date: str = "2026-07-01") -> dict:
    return {
        "date": measurement_date,
        "weight": 70.2,
        "waist": 82.5,
        "body_fat_estimate": 24.5,
        "notes": "Morning measurement.",
    }


async def test_weekly_summary_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.get(f"/weekly-summary?week_start={WEEK_START}")

    assert response.status_code == 401


async def test_weekly_summary_without_week_start_returns_422(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.get("/weekly-summary", headers=_auth_headers(token))

    assert response.status_code == 422


async def test_weekly_summary_with_no_data_returns_controlled_response(
    client: AsyncClient,
) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.get(
        f"/weekly-summary?week_start={WEEK_START}", headers=_auth_headers(token)
    )

    assert response.status_code == 200
    body = response.json()

    assert body["period"] == {"week_start": "2026-07-01", "week_end": "2026-07-07"}

    assert body["workouts"] == {
        "total_logs": 0,
        "total_sets": 0,
        "total_reps": 0,
        "unique_exercises": 0,
        "workout_days": 0,
    }

    assert body["nutrition"]["days_logged"] == 0
    assert body["nutrition"]["avg_calories"] is None
    assert body["nutrition"]["avg_protein"] is None
    assert body["nutrition"]["avg_carbs"] is None
    assert body["nutrition"]["avg_fats"] is None
    assert body["nutrition"]["total_calories"] == 0

    assert body["measurements"]["measurements_count"] == 0
    assert body["measurements"]["start_weight"] is None

    assert body["data_quality"] == {
        "has_workout_data": False,
        "has_nutrition_data": False,
        "has_measurement_data": False,
        "nutrition_days_logged": 0,
        "measurement_entries": 0,
        "is_ready_for_ai_recommendation": False,
        "missing_data": ["workout_logs", "nutrition_logs", "body_measurements"],
    }


async def test_weekly_summary_consolidates_workout_logs(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    exercise_id = await _create_exercise(client, token)

    await client.post(
        "/workout-logs",
        json=_workout_log_payload(exercise_id, "2026-07-01T08:00:00"),
        headers=_auth_headers(token),
    )
    await client.post(
        "/workout-logs",
        json=_workout_log_payload(exercise_id, "2026-07-03T08:00:00"),
        headers=_auth_headers(token),
    )

    response = await client.get(
        f"/weekly-summary?week_start={WEEK_START}", headers=_auth_headers(token)
    )

    assert response.status_code == 200
    workouts = response.json()["workouts"]
    assert workouts["total_logs"] == 2
    assert workouts["total_sets"] == 8
    assert workouts["total_reps"] == 16
    assert workouts["unique_exercises"] == 1
    assert workouts["workout_days"] == 2


async def test_weekly_summary_consolidates_nutrition_logs(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post(
        "/nutrition-logs", json=_nutrition_log_payload("2026-07-01"), headers=_auth_headers(token)
    )
    await client.post(
        "/nutrition-logs", json=_nutrition_log_payload("2026-07-02"), headers=_auth_headers(token)
    )

    response = await client.get(
        f"/weekly-summary?week_start={WEEK_START}", headers=_auth_headers(token)
    )

    assert response.status_code == 200
    nutrition = response.json()["nutrition"]
    assert nutrition["days_logged"] == 2
    assert nutrition["avg_calories"] == 1850
    assert nutrition["total_calories"] == 3700


async def test_weekly_summary_consolidates_body_measurements(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post(
        "/measurements", json=_measurement_payload("2026-07-01"), headers=_auth_headers(token)
    )
    await client.post(
        "/measurements",
        json={**_measurement_payload("2026-07-07"), "weight": 69.5},
        headers=_auth_headers(token),
    )

    response = await client.get(
        f"/weekly-summary?week_start={WEEK_START}", headers=_auth_headers(token)
    )

    assert response.status_code == 200
    measurements = response.json()["measurements"]
    assert measurements["measurements_count"] == 2
    assert measurements["start_weight"] == 70.2
    assert measurements["end_weight"] == 69.5
    assert measurements["weight_change"] == -0.7


async def test_weekly_summary_is_ready_true_with_minimum_data(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    exercise_id = await _create_exercise(client, token)

    await client.post(
        "/workout-logs",
        json=_workout_log_payload(exercise_id, "2026-07-01T08:00:00"),
        headers=_auth_headers(token),
    )
    await client.post(
        "/nutrition-logs", json=_nutrition_log_payload("2026-07-01"), headers=_auth_headers(token)
    )
    await client.post(
        "/nutrition-logs", json=_nutrition_log_payload("2026-07-02"), headers=_auth_headers(token)
    )
    await client.post(
        "/nutrition-logs", json=_nutrition_log_payload("2026-07-03"), headers=_auth_headers(token)
    )
    await client.post(
        "/measurements", json=_measurement_payload("2026-07-01"), headers=_auth_headers(token)
    )

    response = await client.get(
        f"/weekly-summary?week_start={WEEK_START}", headers=_auth_headers(token)
    )

    assert response.status_code == 200
    data_quality = response.json()["data_quality"]
    assert data_quality["is_ready_for_ai_recommendation"] is True
    assert data_quality["missing_data"] == []


async def test_weekly_summary_is_ready_false_when_missing_data(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post(
        "/nutrition-logs", json=_nutrition_log_payload("2026-07-01"), headers=_auth_headers(token)
    )
    await client.post(
        "/nutrition-logs", json=_nutrition_log_payload("2026-07-02"), headers=_auth_headers(token)
    )

    response = await client.get(
        f"/weekly-summary?week_start={WEEK_START}", headers=_auth_headers(token)
    )

    assert response.status_code == 200
    data_quality = response.json()["data_quality"]
    assert data_quality["is_ready_for_ai_recommendation"] is False
    assert "workout_logs" in data_quality["missing_data"]
    assert "nutrition_logs" in data_quality["missing_data"]
    assert "body_measurements" in data_quality["missing_data"]


async def test_weekly_summary_does_not_leak_other_users_data(client: AsyncClient) -> None:
    owner_token = await _register_and_login(client, "owner@example.com")
    other_token = await _register_and_login(client, "other@example.com")
    exercise_id = await _create_exercise(client, owner_token)

    await client.post(
        "/workout-logs",
        json=_workout_log_payload(exercise_id, "2026-07-01T08:00:00"),
        headers=_auth_headers(owner_token),
    )
    await client.post(
        "/nutrition-logs",
        json=_nutrition_log_payload("2026-07-01"),
        headers=_auth_headers(owner_token),
    )
    await client.post(
        "/measurements",
        json=_measurement_payload("2026-07-01"),
        headers=_auth_headers(owner_token),
    )

    response = await client.get(
        f"/weekly-summary?week_start={WEEK_START}", headers=_auth_headers(other_token)
    )

    assert response.status_code == 200
    body = response.json()
    assert body["workouts"]["total_logs"] == 0
    assert body["nutrition"]["days_logged"] == 0
    assert body["measurements"]["measurements_count"] == 0
