from httpx import AsyncClient

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


def _log_payload(exercise_id: str, performed_at: str = "2026-07-03T18:30:00") -> dict:
    return {
        "exercise_id": exercise_id,
        "performed_at": performed_at,
        "sets": 4,
        "reps": 8,
        "weight": 12.5,
        "notes": "Felt strong, good control on last set.",
    }


async def test_create_workout_log_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.post(
        "/workout-logs", json=_log_payload("00000000-0000-0000-0000-000000000000")
    )

    assert response.status_code == 401


async def test_create_workout_log_with_valid_token_returns_201(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    exercise_id = await _create_exercise(client, token)

    response = await client.post(
        "/workout-logs", json=_log_payload(exercise_id), headers=_auth_headers(token)
    )

    assert response.status_code == 201
    body = response.json()
    assert body["exercise_id"] == exercise_id
    assert body["exercise_name"] == "Pull-ups"
    assert body["sets"] == 4
    assert body["reps"] == 8
    assert body["weight"] == 12.5
    assert body["notes"] == "Felt strong, good control on last set."


async def test_create_workout_log_with_nonexistent_exercise_returns_404(
    client: AsyncClient,
) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.post(
        "/workout-logs",
        json=_log_payload("00000000-0000-0000-0000-000000000000"),
        headers=_auth_headers(token),
    )

    assert response.status_code == 404


async def test_create_workout_log_with_another_users_exercise_returns_404(
    client: AsyncClient,
) -> None:
    owner_token = await _register_and_login(client, "owner@example.com")
    other_token = await _register_and_login(client, "other@example.com")
    exercise_id = await _create_exercise(client, owner_token)

    response = await client.post(
        "/workout-logs", json=_log_payload(exercise_id), headers=_auth_headers(other_token)
    )

    assert response.status_code == 404


async def test_list_workout_logs_returns_only_own_logs(client: AsyncClient) -> None:
    owner_token = await _register_and_login(client, "owner@example.com")
    other_token = await _register_and_login(client, "other@example.com")
    exercise_id = await _create_exercise(client, owner_token)

    await client.post(
        "/workout-logs", json=_log_payload(exercise_id), headers=_auth_headers(owner_token)
    )

    owner_response = await client.get("/workout-logs", headers=_auth_headers(owner_token))
    other_response = await client.get("/workout-logs", headers=_auth_headers(other_token))

    assert owner_response.status_code == 200
    assert len(owner_response.json()) == 1

    assert other_response.status_code == 200
    assert other_response.json() == []


async def test_list_workout_logs_respects_date_range_filters(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    exercise_id = await _create_exercise(client, token)

    await client.post(
        "/workout-logs",
        json=_log_payload(exercise_id, "2026-06-15T18:30:00"),
        headers=_auth_headers(token),
    )
    await client.post(
        "/workout-logs",
        json=_log_payload(exercise_id, "2026-07-03T18:30:00"),
        headers=_auth_headers(token),
    )

    response = await client.get(
        "/workout-logs?date_from=2026-07-01&date_to=2026-07-07",
        headers=_auth_headers(token),
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["performed_at"].startswith("2026-07-03")


async def test_workout_logs_summary_returns_correct_aggregates(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    exercise_id = await _create_exercise(client, token)

    await client.post(
        "/workout-logs",
        json=_log_payload(exercise_id, "2026-07-01T08:00:00"),
        headers=_auth_headers(token),
    )
    await client.post(
        "/workout-logs",
        json=_log_payload(exercise_id, "2026-07-03T08:00:00"),
        headers=_auth_headers(token),
    )

    response = await client.get("/workout-logs/summary", headers=_auth_headers(token))

    assert response.status_code == 200
    body = response.json()
    assert body["total_logs"] == 2
    assert body["total_sets"] == 8
    assert body["total_reps"] == 16
    assert body["unique_exercises"] == 1
    assert body["workout_days"] == 2


async def test_create_workout_log_with_invalid_payload_returns_422(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    exercise_id = await _create_exercise(client, token)
    invalid_payload = {
        "exercise_id": exercise_id,
        "performed_at": "2026-07-03T18:30:00",
        "sets": 0,
        "reps": 8,
    }

    response = await client.post(
        "/workout-logs", json=invalid_payload, headers=_auth_headers(token)
    )

    assert response.status_code == 422
