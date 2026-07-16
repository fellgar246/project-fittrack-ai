from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
from azure.core.exceptions import AzureError
from httpx import AsyncClient

from app.core.config import settings
from app.main import app
from app.services.progress_photo_storage import (
    ALLOWED_CONTENT_TYPES,
    AzureBlobProgressPhotoStorage,
    FakeProgressPhotoStorage,
    ProgressPhotoStorageAuthorizationError,
    ProgressPhotoStorageNotConfiguredError,
    ProgressPhotoStorageUnavailableError,
    build_blob_name,
    get_progress_photo_storage,
    validate_content_type,
    validate_size_bytes,
)


def _upload_payload(
    *,
    content_type: str = "image/jpeg",
    size_bytes: int = 123456,
    captured_at: str = "2026-07-15",
) -> dict:
    return {
        "captured_at": captured_at,
        "content_type": content_type,
        "size_bytes": size_bytes,
        "notes": "Optional note",
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


@pytest.fixture
def fake_storage() -> FakeProgressPhotoStorage:
    storage = FakeProgressPhotoStorage()
    app.dependency_overrides[get_progress_photo_storage] = lambda: storage
    yield storage
    app.dependency_overrides.pop(get_progress_photo_storage, None)


async def test_upload_request_requires_auth(client: AsyncClient) -> None:
    response = await client.post("/progress-photos/upload-requests", json=_upload_payload())
    assert response.status_code == 401


async def test_upload_request_valid_jpeg(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "photo-owner@example.com")

    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(content_type="image/jpeg"),
        headers=_auth_headers(token),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["photo_id"]
    assert body["upload_url"].startswith("https://fake-storage.example/")
    assert body["expires_at"]
    assert body["required_headers"]["Content-Type"] == "image/jpeg"
    assert body["required_headers"]["x-ms-blob-type"] == "BlockBlob"
    assert body["required_headers"]["Cache-Control"] == "no-store"


@pytest.mark.parametrize("content_type", ["image/png", "image/webp"])
async def test_upload_request_valid_mime_types(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage, content_type: str
) -> None:
    token = await _register_and_login(client, f"{content_type}@example.com")

    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(content_type=content_type),
        headers=_auth_headers(token),
    )

    assert response.status_code == 201
    assert response.json()["required_headers"]["Content-Type"] == content_type


@pytest.mark.parametrize(
    "content_type",
    ["image/svg+xml", "image/gif", "application/pdf", "text/plain"],
)
async def test_upload_request_rejects_invalid_mime(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage, content_type: str
) -> None:
    token = await _register_and_login(client, f"invalid-{content_type}@example.com")

    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(content_type=content_type),
        headers=_auth_headers(token),
    )

    assert response.status_code == 415


async def test_upload_request_rejects_zero_size(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "zero-size@example.com")

    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(size_bytes=0),
        headers=_auth_headers(token),
    )

    assert response.status_code == 422


async def test_upload_request_rejects_oversized_file(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "progress_photo_max_bytes", 1024)
    token = await _register_and_login(client, "oversized@example.com")

    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(size_bytes=2048),
        headers=_auth_headers(token),
    )

    assert response.status_code == 413


async def test_upload_request_uses_backend_blob_name(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "blob-name@example.com")

    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(),
        headers=_auth_headers(token),
    )

    photo_id = response.json()["photo_id"]
    assert f"/progress-photos/{photo_id}/" in response.json()["upload_url"]


async def test_upload_request_provider_failure_returns_502(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    fake_storage.set_upload_failures(True)
    token = await _register_and_login(client, "provider-fail@example.com")

    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(),
        headers=_auth_headers(token),
    )

    assert response.status_code == 502


async def test_upload_request_storage_unavailable_returns_503(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    fake_storage.set_unavailable(True)
    token = await _register_and_login(client, "storage-down@example.com")

    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(),
        headers=_auth_headers(token),
    )

    assert response.status_code == 503


async def _create_pending_photo(
    client: AsyncClient,
    fake_storage: FakeProgressPhotoStorage,
    token: str,
) -> str:
    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(),
        headers=_auth_headers(token),
    )
    photo_id = response.json()["photo_id"]
    upload_url = response.json()["upload_url"]
    blob_name = upload_url.split("/progress-photos/", 1)[1].split("?", 1)[0]
    fake_storage.simulate_upload(
        blob_name,
        content_type="image/jpeg",
        size_bytes=123456,
    )
    return photo_id


async def test_confirm_upload_success(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "confirm-ok@example.com")
    photo_id = await _create_pending_photo(client, fake_storage, token)

    response = await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "active"
    assert body["confirmed_at"] is not None


async def test_confirm_upload_other_user_returns_404(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    owner_token = await _register_and_login(client, "owner-photo@example.com")
    other_token = await _register_and_login(client, "other-photo@example.com")
    photo_id = await _create_pending_photo(client, fake_storage, owner_token)

    response = await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(other_token),
    )

    assert response.status_code == 404


async def test_confirm_upload_missing_blob_returns_409(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "missing-blob@example.com")
    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(),
        headers=_auth_headers(token),
    )
    photo_id = response.json()["photo_id"]

    confirm = await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(token),
    )

    assert confirm.status_code == 409


async def test_confirm_upload_content_type_mismatch_marks_invalid(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "mime-mismatch@example.com")
    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(content_type="image/jpeg"),
        headers=_auth_headers(token),
    )
    photo_id = response.json()["photo_id"]
    blob_name = response.json()["upload_url"].split("/progress-photos/", 1)[1].split("?", 1)[0]
    fake_storage.simulate_upload(
        blob_name,
        content_type="image/png",
        size_bytes=123456,
    )

    confirm = await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(token),
    )

    assert confirm.status_code == 409


async def test_confirm_upload_idempotent_for_active_photo(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "idempotent@example.com")
    photo_id = await _create_pending_photo(client, fake_storage, token)

    first = await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(token),
    )
    second = await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(token),
    )

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json() == second.json()


async def test_list_returns_only_active_photos(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "list-active@example.com")
    photo_id = await _create_pending_photo(client, fake_storage, token)
    await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(token),
    )

    response = await client.get("/progress-photos", headers=_auth_headers(token))

    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["status"] == "active"


async def test_list_isolates_users(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    owner_token = await _register_and_login(client, "list-owner@example.com")
    other_token = await _register_and_login(client, "list-other@example.com")
    photo_id = await _create_pending_photo(client, fake_storage, owner_token)
    await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(owner_token),
    )

    owner_list = await client.get("/progress-photos", headers=_auth_headers(owner_token))
    other_list = await client.get("/progress-photos", headers=_auth_headers(other_token))

    assert len(owner_list.json()) == 1
    assert other_list.json() == []


async def test_access_returns_temporary_url(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "access-url@example.com")
    photo_id = await _create_pending_photo(client, fake_storage, token)
    await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(token),
    )

    response = await client.post(
        f"/progress-photos/{photo_id}/access",
        headers=_auth_headers(token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["photo_id"] == photo_id
    assert body["access_url"].startswith("https://fake-storage.example/")
    assert body["expires_at"]


async def test_access_other_user_returns_404(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    owner_token = await _register_and_login(client, "access-owner@example.com")
    other_token = await _register_and_login(client, "access-other@example.com")
    photo_id = await _create_pending_photo(client, fake_storage, owner_token)
    await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(owner_token),
    )

    response = await client.post(
        f"/progress-photos/{photo_id}/access",
        headers=_auth_headers(other_token),
    )

    assert response.status_code == 404


def test_build_blob_name_uses_backend_path() -> None:
    user_id = uuid4()
    photo_id = uuid4()
    blob_name = build_blob_name(user_id, photo_id, "image/jpeg")

    assert blob_name.startswith(f"users/{user_id}/progress-photos/{photo_id}/")
    assert blob_name.endswith(".jpg")


def test_validate_content_type_rejects_svg() -> None:
    with pytest.raises(ValueError):
        validate_content_type("image/svg+xml")


def test_validate_size_bytes_rejects_over_limit(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "progress_photo_max_bytes", 100)
    with pytest.raises(ValueError):
        validate_size_bytes(101)


async def test_fake_provider_simulates_missing_blob() -> None:
    storage = FakeProgressPhotoStorage()
    assert await storage.get_blob_metadata("missing") is None


async def test_azure_provider_not_configured(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "azure_storage_account_name", "")
    provider = AzureBlobProgressPhotoStorage()

    with pytest.raises(ProgressPhotoStorageNotConfiguredError):
        await provider.create_upload_authorization(
            blob_name="users/a/progress-photos/b/c.jpg",
            content_type="image/jpeg",
            expires_at=datetime.utcnow() + timedelta(minutes=5),
        )


async def test_azure_provider_generate_upload_authorization(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "azure_storage_account_name", "exampleaccount")
    monkeypatch.setattr(settings, "azure_storage_container_name", "progress-photos")

    delegation_key = MagicMock()
    delegation_key.value = "YWJjZGVmZ2hpams="
    mock_client = AsyncMock()
    mock_client.get_user_delegation_key = AsyncMock(return_value=delegation_key)
    provider = AzureBlobProgressPhotoStorage(blob_service_client=mock_client)

    result = await provider.create_upload_authorization(
        blob_name="users/a/progress-photos/b/c.jpg",
        content_type="image/jpeg",
        expires_at=datetime.utcnow() + timedelta(minutes=5),
    )

    assert result.upload_url.startswith("https://exampleaccount.blob.core.windows.net/")
    assert "sig=" in result.upload_url


async def test_azure_provider_unavailable_on_metadata_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "azure_storage_account_name", "exampleaccount")
    monkeypatch.setattr(settings, "azure_storage_container_name", "progress-photos")

    mock_blob_client = AsyncMock()
    mock_blob_client.get_blob_properties = AsyncMock(side_effect=AzureError("boom"))
    mock_client = MagicMock()
    mock_client.get_blob_client.return_value = mock_blob_client
    provider = AzureBlobProgressPhotoStorage(blob_service_client=mock_client)

    with pytest.raises(ProgressPhotoStorageUnavailableError):
        await provider.get_blob_metadata("users/a/progress-photos/b/c.jpg")


async def test_get_progress_photo_storage_defaults_to_fake(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(settings, "progress_photo_storage_provider", "fake")
    storage = get_progress_photo_storage()
    assert isinstance(storage, FakeProgressPhotoStorage)


def test_allowed_content_types_cover_expected_extensions() -> None:
    assert set(ALLOWED_CONTENT_TYPES.values()) == {"jpg", "png", "webp"}


async def test_fake_provider_authorization_errors() -> None:
    storage = FakeProgressPhotoStorage()
    storage.set_read_failures(True)
    with pytest.raises(ProgressPhotoStorageAuthorizationError):
        await storage.create_read_authorization(
            blob_name="users/a/progress-photos/b/c.jpg",
            expires_at=datetime.utcnow() + timedelta(minutes=5),
        )


async def test_fake_provider_metadata_error() -> None:
    storage = FakeProgressPhotoStorage()
    storage.set_metadata_failures(True)
    with pytest.raises(Exception):
        await storage.get_blob_metadata("users/a/progress-photos/b/c.jpg")


async def test_confirm_upload_size_mismatch(
    client: AsyncClient, fake_storage: FakeProgressPhotoStorage
) -> None:
    token = await _register_and_login(client, "size-mismatch@example.com")
    response = await client.post(
        "/progress-photos/upload-requests",
        json=_upload_payload(size_bytes=123456),
        headers=_auth_headers(token),
    )
    photo_id = response.json()["photo_id"]
    blob_name = response.json()["upload_url"].split("/progress-photos/", 1)[1].split("?", 1)[0]
    fake_storage.simulate_upload(
        blob_name,
        content_type="image/jpeg",
        size_bytes=999999,
    )

    confirm = await client.post(
        f"/progress-photos/{photo_id}/confirm",
        headers=_auth_headers(token),
    )

    assert confirm.status_code == 409
