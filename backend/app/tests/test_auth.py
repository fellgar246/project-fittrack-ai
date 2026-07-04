from httpx import AsyncClient

REGISTER_PAYLOAD = {
    "email": "felipe@example.com",
    "name": "Felipe Garcia",
    "password": "StrongPassword123",
    "goal": "body recomposition",
}


async def test_register_success(client: AsyncClient) -> None:
    response = await client.post("/auth/register", json=REGISTER_PAYLOAD)

    assert response.status_code == 201
    body = response.json()
    assert body["email"] == REGISTER_PAYLOAD["email"]
    assert body["name"] == REGISTER_PAYLOAD["name"]
    assert body["goal"] == REGISTER_PAYLOAD["goal"]
    assert "password" not in body
    assert "password_hash" not in body


async def test_register_duplicate_email_returns_409(client: AsyncClient) -> None:
    await client.post("/auth/register", json=REGISTER_PAYLOAD)
    response = await client.post("/auth/register", json=REGISTER_PAYLOAD)

    assert response.status_code == 409


async def test_login_success_returns_access_token(client: AsyncClient) -> None:
    await client.post("/auth/register", json=REGISTER_PAYLOAD)

    response = await client.post(
        "/auth/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert body["token_type"] == "bearer"


async def test_login_wrong_password_returns_401(client: AsyncClient) -> None:
    await client.post("/auth/register", json=REGISTER_PAYLOAD)

    response = await client.post(
        "/auth/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": "wrong-password"},
    )

    assert response.status_code == 401


async def test_me_with_valid_token_returns_user(client: AsyncClient) -> None:
    await client.post("/auth/register", json=REGISTER_PAYLOAD)
    login_response = await client.post(
        "/auth/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
    )
    token = login_response.json()["access_token"]

    response = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["email"] == REGISTER_PAYLOAD["email"]


async def test_me_without_token_returns_401(client: AsyncClient) -> None:
    response = await client.get("/auth/me")

    assert response.status_code == 401
