from httpx import AsyncClient


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


def _log_payload(log_date: str = "2026-07-03") -> dict:
    return {
        "date": log_date,
        "calories": 1850,
        "protein": 105.5,
        "carbs": 210,
        "fats": 55,
        "notes": "Good protein intake, slightly low calories.",
    }


async def test_create_nutrition_log_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.post("/nutrition-logs", json=_log_payload())

    assert response.status_code == 401


async def test_create_nutrition_log_with_valid_token_returns_201(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.post(
        "/nutrition-logs", json=_log_payload(), headers=_auth_headers(token)
    )

    assert response.status_code == 201
    body = response.json()
    assert body["date"] == "2026-07-03"
    assert body["calories"] == 1850
    assert body["protein"] == 105.5
    assert body["carbs"] == 210
    assert body["fats"] == 55
    assert body["notes"] == "Good protein intake, slightly low calories."


async def test_create_nutrition_log_duplicate_date_returns_409(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post("/nutrition-logs", json=_log_payload(), headers=_auth_headers(token))
    response = await client.post(
        "/nutrition-logs", json=_log_payload(), headers=_auth_headers(token)
    )

    assert response.status_code == 409


async def test_create_nutrition_log_same_date_different_users_returns_201(
    client: AsyncClient,
) -> None:
    token_a = await _register_and_login(client, "usera@example.com")
    token_b = await _register_and_login(client, "userb@example.com")

    response_a = await client.post(
        "/nutrition-logs", json=_log_payload(), headers=_auth_headers(token_a)
    )
    response_b = await client.post(
        "/nutrition-logs", json=_log_payload(), headers=_auth_headers(token_b)
    )

    assert response_a.status_code == 201
    assert response_b.status_code == 201


async def test_list_nutrition_logs_returns_only_own_logs(client: AsyncClient) -> None:
    owner_token = await _register_and_login(client, "owner@example.com")
    other_token = await _register_and_login(client, "other@example.com")

    await client.post(
        "/nutrition-logs", json=_log_payload(), headers=_auth_headers(owner_token)
    )

    owner_response = await client.get("/nutrition-logs", headers=_auth_headers(owner_token))
    other_response = await client.get("/nutrition-logs", headers=_auth_headers(other_token))

    assert owner_response.status_code == 200
    assert len(owner_response.json()) == 1

    assert other_response.status_code == 200
    assert other_response.json() == []


async def test_list_nutrition_logs_respects_date_range_filters(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post(
        "/nutrition-logs", json=_log_payload("2026-06-15"), headers=_auth_headers(token)
    )
    await client.post(
        "/nutrition-logs", json=_log_payload("2026-07-03"), headers=_auth_headers(token)
    )

    response = await client.get(
        "/nutrition-logs?date_from=2026-07-01&date_to=2026-07-07",
        headers=_auth_headers(token),
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["date"] == "2026-07-03"


async def test_nutrition_logs_summary_returns_correct_aggregates(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post(
        "/nutrition-logs",
        json={
            "date": "2026-07-01",
            "calories": 1800,
            "protein": 100,
            "carbs": 200,
            "fats": 50,
        },
        headers=_auth_headers(token),
    )
    await client.post(
        "/nutrition-logs",
        json={
            "date": "2026-07-03",
            "calories": 1900,
            "protein": 110,
            "carbs": 210,
            "fats": 60,
        },
        headers=_auth_headers(token),
    )

    response = await client.get(
        "/nutrition-logs/summary?date_from=2026-07-01&date_to=2026-07-07",
        headers=_auth_headers(token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["days_logged"] == 2
    assert body["avg_calories"] == 1850
    assert body["avg_protein"] == 105
    assert body["avg_carbs"] == 205
    assert body["avg_fats"] == 55
    assert body["total_calories"] == 3700
    assert body["total_protein"] == 210
    assert body["total_carbs"] == 410
    assert body["total_fats"] == 110


async def test_create_nutrition_log_with_invalid_payload_returns_422(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    invalid_payload = {
        "date": "2026-07-03",
        "calories": -1,
        "protein": 100,
        "carbs": 200,
        "fats": 50,
    }

    response = await client.post(
        "/nutrition-logs", json=invalid_payload, headers=_auth_headers(token)
    )

    assert response.status_code == 422
