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


def _measurement_payload(measurement_date: str = "2026-07-03") -> dict:
    return {
        "date": measurement_date,
        "weight": 70.2,
        "waist": 82.5,
        "body_fat_estimate": 24.5,
        "notes": "Morning measurement after cardio day.",
    }


async def test_create_measurement_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.post("/measurements", json=_measurement_payload())

    assert response.status_code == 401


async def test_create_measurement_with_valid_token_returns_201(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.post(
        "/measurements", json=_measurement_payload(), headers=_auth_headers(token)
    )

    assert response.status_code == 201
    body = response.json()
    assert body["date"] == "2026-07-03"
    assert body["weight"] == 70.2
    assert body["waist"] == 82.5
    assert body["body_fat_estimate"] == 24.5
    assert body["notes"] == "Morning measurement after cardio day."


async def test_create_measurement_duplicate_date_returns_409(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post(
        "/measurements", json=_measurement_payload(), headers=_auth_headers(token)
    )
    response = await client.post(
        "/measurements", json=_measurement_payload(), headers=_auth_headers(token)
    )

    assert response.status_code == 409


async def test_create_measurement_same_date_different_users_returns_201(
    client: AsyncClient,
) -> None:
    token_a = await _register_and_login(client, "usera@example.com")
    token_b = await _register_and_login(client, "userb@example.com")

    response_a = await client.post(
        "/measurements", json=_measurement_payload(), headers=_auth_headers(token_a)
    )
    response_b = await client.post(
        "/measurements", json=_measurement_payload(), headers=_auth_headers(token_b)
    )

    assert response_a.status_code == 201
    assert response_b.status_code == 201


async def test_list_measurements_returns_only_own_measurements(client: AsyncClient) -> None:
    owner_token = await _register_and_login(client, "owner@example.com")
    other_token = await _register_and_login(client, "other@example.com")

    await client.post(
        "/measurements", json=_measurement_payload(), headers=_auth_headers(owner_token)
    )

    owner_response = await client.get("/measurements", headers=_auth_headers(owner_token))
    other_response = await client.get("/measurements", headers=_auth_headers(other_token))

    assert owner_response.status_code == 200
    assert len(owner_response.json()) == 1

    assert other_response.status_code == 200
    assert other_response.json() == []


async def test_list_measurements_respects_date_range_filters(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post(
        "/measurements", json=_measurement_payload("2026-06-15"), headers=_auth_headers(token)
    )
    await client.post(
        "/measurements", json=_measurement_payload("2026-07-03"), headers=_auth_headers(token)
    )

    response = await client.get(
        "/measurements?date_from=2026-07-01&date_to=2026-07-07",
        headers=_auth_headers(token),
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["date"] == "2026-07-03"


async def test_measurements_progress_returns_correct_changes(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")

    await client.post(
        "/measurements",
        json={
            "date": "2026-07-01",
            "weight": 71.0,
            "waist": 83.2,
            "body_fat_estimate": 25.0,
        },
        headers=_auth_headers(token),
    )
    await client.post(
        "/measurements",
        json={
            "date": "2026-07-31",
            "weight": 70.2,
            "waist": 82.5,
            "body_fat_estimate": 24.5,
        },
        headers=_auth_headers(token),
    )

    response = await client.get(
        "/measurements/progress?date_from=2026-07-01&date_to=2026-07-31",
        headers=_auth_headers(token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["measurements_count"] == 2
    assert body["start_date"] == "2026-07-01"
    assert body["end_date"] == "2026-07-31"
    assert body["start_weight"] == 71.0
    assert body["end_weight"] == 70.2
    assert body["weight_change"] == -0.8
    assert body["start_waist"] == 83.2
    assert body["end_waist"] == 82.5
    assert body["waist_change"] == -0.7
    assert body["start_body_fat_estimate"] == 25.0
    assert body["end_body_fat_estimate"] == 24.5
    assert body["body_fat_change"] == -0.5


async def test_measurements_progress_without_data_returns_controlled_response(
    client: AsyncClient,
) -> None:
    token = await _register_and_login(client, "owner@example.com")

    response = await client.get("/measurements/progress", headers=_auth_headers(token))

    assert response.status_code == 200
    body = response.json()
    assert body["measurements_count"] == 0
    assert body["start_date"] is None
    assert body["end_date"] is None
    assert body["start_weight"] is None
    assert body["end_weight"] is None
    assert body["weight_change"] is None
    assert body["start_waist"] is None
    assert body["end_waist"] is None
    assert body["waist_change"] is None
    assert body["start_body_fat_estimate"] is None
    assert body["end_body_fat_estimate"] is None
    assert body["body_fat_change"] is None


async def test_create_measurement_with_invalid_payload_returns_422(client: AsyncClient) -> None:
    token = await _register_and_login(client, "owner@example.com")
    invalid_payload = {
        "date": "2026-07-03",
        "weight": 0,
        "waist": 82.5,
        "body_fat_estimate": 24.5,
    }

    response = await client.post(
        "/measurements", json=invalid_payload, headers=_auth_headers(token)
    )

    assert response.status_code == 422
