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
                {
                    "name": "Dumbbell Press",
                    "muscle_group": "chest",
                    "target_sets": 3,
                    "target_reps": "8-10",
                },
            ],
        },
        {
            "day_of_week": 3,
            "title": "Lower Body",
            "exercises": [
                {
                    "name": "Goblet Squat",
                    "muscle_group": "legs",
                    "target_sets": 4,
                    "target_reps": "10-12",
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


async def test_create_workout_plan_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.post("/workout-plans", json=PLAN_PAYLOAD)

    assert response.status_code == 401


async def test_create_workout_plan_with_valid_token_returns_201(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.post(
        "/workout-plans", json=PLAN_PAYLOAD, headers=_auth_headers(token)
    )

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == PLAN_PAYLOAD["name"]
    assert body["goal"] == PLAN_PAYLOAD["goal"]
    assert body["active"] is True
    assert body["days_count"] == 2
    assert body["exercises_count"] == 3


async def test_list_workout_plans_returns_only_own_plans(client: AsyncClient) -> None:
    owner_token = await _register_and_login(client, "owner@example.com")
    other_token = await _register_and_login(client, "other@example.com")

    await client.post("/workout-plans", json=PLAN_PAYLOAD, headers=_auth_headers(owner_token))

    owner_response = await client.get("/workout-plans", headers=_auth_headers(owner_token))
    other_response = await client.get("/workout-plans", headers=_auth_headers(other_token))

    assert owner_response.status_code == 200
    assert len(owner_response.json()) == 1

    assert other_response.status_code == 200
    assert other_response.json() == []


async def test_get_workout_plan_detail_returns_nested_days_and_exercises(
    client: AsyncClient,
) -> None:
    token = await _register_and_login(client, "owner@example.com")
    create_response = await client.post(
        "/workout-plans", json=PLAN_PAYLOAD, headers=_auth_headers(token)
    )
    plan_id = create_response.json()["id"]

    response = await client.get(f"/workout-plans/{plan_id}", headers=_auth_headers(token))

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == PLAN_PAYLOAD["name"]
    assert len(body["days"]) == 2
    assert body["days"][0]["day_of_week"] == 1
    assert len(body["days"][0]["exercises"]) == 2
    assert body["days"][0]["exercises"][0]["name"] == "Pull-ups"


async def test_get_workout_plan_of_another_user_returns_404(client: AsyncClient) -> None:
    owner_token = await _register_and_login(client, "owner@example.com")
    other_token = await _register_and_login(client, "other@example.com")

    create_response = await client.post(
        "/workout-plans", json=PLAN_PAYLOAD, headers=_auth_headers(owner_token)
    )
    plan_id = create_response.json()["id"]

    response = await client.get(f"/workout-plans/{plan_id}", headers=_auth_headers(other_token))

    assert response.status_code == 404


async def test_get_nonexistent_workout_plan_returns_404(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.get(
        "/workout-plans/00000000-0000-0000-0000-000000000000", headers=_auth_headers(token)
    )

    assert response.status_code == 404


async def test_create_workout_plan_with_invalid_payload_returns_422(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    invalid_payload = {
        "name": "Invalid Plan",
        "goal": "body recomposition",
        "days": [{"day_of_week": 9, "title": "Bad Day", "exercises": []}],
    }

    response = await client.post(
        "/workout-plans", json=invalid_payload, headers=_auth_headers(token)
    )

    assert response.status_code == 422
