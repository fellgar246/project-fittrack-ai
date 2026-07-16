"""Progress photo blob storage abstraction.

Routes and services depend on this interface instead of the Azure SDK directly.
The default fake provider is deterministic and requires no credentials, which
keeps local development and tests stable. ``AzureBlobProgressPhotoStorage``
implements user-delegation SAS against a private container, selected via
``PROGRESS_PHOTO_STORAGE_PROVIDER=azure``.
"""

from __future__ import annotations

import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from azure.core.exceptions import AzureError, HttpResponseError
from azure.identity.aio import DefaultAzureCredential
from azure.storage.blob import BlobSasPermissions, generate_blob_sas
from azure.storage.blob.aio import BlobServiceClient

from app.core.config import settings

ALLOWED_CONTENT_TYPES: dict[str, str] = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}

REJECTED_CONTENT_TYPES = frozenset(
    {
        "image/svg+xml",
        "image/gif",
        "image/heic",
        "image/heif",
        "application/octet-stream",
    }
)

UPLOAD_REQUIRED_HEADERS = {
    "x-ms-blob-type": "BlockBlob",
    "Cache-Control": "no-store",
}


@dataclass(frozen=True)
class BlobMetadata:
    content_type: str
    size_bytes: int
    exists: bool = True


@dataclass(frozen=True)
class UploadAuthorizationResult:
    upload_url: str
    expires_at: datetime
    required_headers: dict[str, str]


@dataclass(frozen=True)
class ReadAuthorizationResult:
    access_url: str
    expires_at: datetime


class ProgressPhotoStorageError(Exception):
    """Raised when storage fails in a way callers should treat as upstream failure."""


class ProgressPhotoStorageNotConfiguredError(ProgressPhotoStorageError):
    """Raised when azure provider is selected without full configuration."""


class ProgressPhotoStorageUnavailableError(ProgressPhotoStorageError):
    """Raised when storage is unreachable or not configured for use."""


class ProgressPhotoStorageAuthorizationError(ProgressPhotoStorageError):
    """Raised when SAS generation fails."""


class ProgressPhotoStorage(ABC):
    @abstractmethod
    async def create_upload_authorization(
        self,
        *,
        blob_name: str,
        content_type: str,
        expires_at: datetime,
    ) -> UploadAuthorizationResult:
        """Return a short-lived URL and headers for a single blob upload."""

    @abstractmethod
    async def get_blob_metadata(self, blob_name: str) -> BlobMetadata | None:
        """Return blob metadata when the blob exists, otherwise None."""

    @abstractmethod
    async def create_read_authorization(
        self,
        *,
        blob_name: str,
        expires_at: datetime,
    ) -> ReadAuthorizationResult:
        """Return a short-lived read URL for a single blob."""

    @abstractmethod
    async def delete_blob(self, blob_name: str) -> None:
        """Delete a blob when cleanup is required."""


class FakeProgressPhotoStorage(ProgressPhotoStorage):
    """Deterministic in-memory storage for tests and local smoke flows."""

    def __init__(self) -> None:
        self._blobs: dict[str, BlobMetadata] = {}
        self._upload_failures = False
        self._read_failures = False
        self._metadata_failures = False
        self._delete_failures = False
        self._unavailable = False

    def simulate_upload(
        self,
        blob_name: str,
        *,
        content_type: str,
        size_bytes: int,
    ) -> None:
        self._blobs[blob_name] = BlobMetadata(
            content_type=content_type,
            size_bytes=size_bytes,
        )

    def set_upload_failures(self, enabled: bool) -> None:
        self._upload_failures = enabled

    def set_read_failures(self, enabled: bool) -> None:
        self._read_failures = enabled

    def set_metadata_failures(self, enabled: bool) -> None:
        self._metadata_failures = enabled

    def set_delete_failures(self, enabled: bool) -> None:
        self._delete_failures = enabled

    def set_unavailable(self, enabled: bool) -> None:
        self._unavailable = enabled

    def _ensure_available(self) -> None:
        if self._unavailable:
            raise ProgressPhotoStorageUnavailableError("Storage provider unavailable")

    async def create_upload_authorization(
        self,
        *,
        blob_name: str,
        content_type: str,
        expires_at: datetime,
    ) -> UploadAuthorizationResult:
        self._ensure_available()
        if self._upload_failures:
            raise ProgressPhotoStorageAuthorizationError("Failed to generate upload SAS")

        required_headers = {
            **UPLOAD_REQUIRED_HEADERS,
            "Content-Type": content_type,
        }
        upload_url = (
            f"https://fake-storage.example/{settings.azure_storage_container_name}/"
            f"{blob_name}?sp=c&se={int(expires_at.timestamp())}&sig=<redacted>"
        )
        return UploadAuthorizationResult(
            upload_url=upload_url,
            expires_at=expires_at,
            required_headers=required_headers,
        )

    async def get_blob_metadata(self, blob_name: str) -> BlobMetadata | None:
        self._ensure_available()
        if self._metadata_failures:
            raise ProgressPhotoStorageError("Failed to read blob metadata")
        return self._blobs.get(blob_name)

    async def create_read_authorization(
        self,
        *,
        blob_name: str,
        expires_at: datetime,
    ) -> ReadAuthorizationResult:
        self._ensure_available()
        if self._read_failures:
            raise ProgressPhotoStorageAuthorizationError("Failed to generate read SAS")

        access_url = (
            f"https://fake-storage.example/{settings.azure_storage_container_name}/"
            f"{blob_name}?sp=r&se={int(expires_at.timestamp())}&sig=<redacted>"
        )
        return ReadAuthorizationResult(access_url=access_url, expires_at=expires_at)

    async def delete_blob(self, blob_name: str) -> None:
        self._ensure_available()
        if self._delete_failures:
            raise ProgressPhotoStorageError("Failed to delete blob")
        self._blobs.pop(blob_name, None)


class AzureBlobProgressPhotoStorage(ProgressPhotoStorage):
    """Azure Blob Storage provider using user-delegation SAS."""

    def __init__(
        self,
        *,
        blob_service_client: BlobServiceClient | None = None,
        credential: DefaultAzureCredential | None = None,
    ) -> None:
        self._client = blob_service_client
        self._credential = credential
        self._owns_client = blob_service_client is None

    def _validate_configuration(self) -> tuple[str, str]:
        missing = [
            name
            for name, value in {
                "AZURE_STORAGE_ACCOUNT_NAME": settings.azure_storage_account_name,
                "AZURE_STORAGE_CONTAINER_NAME": settings.azure_storage_container_name,
            }.items()
            if not value
        ]
        if missing:
            raise ProgressPhotoStorageNotConfiguredError(
                "Azure progress photo storage is not configured. Missing: " + ", ".join(missing)
            )
        return settings.azure_storage_account_name, settings.azure_storage_container_name

    async def _get_client(self) -> BlobServiceClient:
        if self._client is not None:
            return self._client

        account_name, _ = self._validate_configuration()
        account_url = f"https://{account_name}.blob.core.windows.net"
        credential_kwargs = {}
        if settings.azure_client_id:
            credential_kwargs["managed_identity_client_id"] = settings.azure_client_id
        credential = self._credential or DefaultAzureCredential(**credential_kwargs)
        self._client = BlobServiceClient(account_url=account_url, credential=credential)
        return self._client

    async def close(self) -> None:
        if self._client is not None and self._owns_client:
            await self._client.close()
            self._client = None
        if self._credential is not None:
            await self._credential.close()
            self._credential = None

    async def _user_delegation_key(
        self, client: BlobServiceClient, start: datetime, expiry: datetime
    ):
        try:
            return await client.get_user_delegation_key(
                key_start_time=start,
                key_expiry_time=expiry,
            )
        except HttpResponseError as exc:
            if exc.status_code in {401, 403}:
                raise ProgressPhotoStorageNotConfiguredError(
                    "Azure storage credentials are not authorized"
                ) from exc
            raise ProgressPhotoStorageError("Failed to obtain user delegation key") from exc
        except AzureError as exc:
            raise ProgressPhotoStorageUnavailableError("Azure storage unavailable") from exc

    async def create_upload_authorization(
        self,
        *,
        blob_name: str,
        content_type: str,
        expires_at: datetime,
    ) -> UploadAuthorizationResult:
        account_name, container_name = self._validate_configuration()
        client = await self._get_client()
        start = datetime.now(UTC) - timedelta(minutes=5)
        try:
            delegation_key = await self._user_delegation_key(client, start, expires_at)
            sas_token = generate_blob_sas(
                account_name=account_name,
                container_name=container_name,
                blob_name=blob_name,
                user_delegation_key=delegation_key,
                permission=BlobSasPermissions(create=True),
                expiry=expires_at,
                start=start,
                protocol="https",
                content_type=content_type,
            )
        except ProgressPhotoStorageError:
            raise
        except AzureError as exc:
            raise ProgressPhotoStorageAuthorizationError(
                "Failed to generate upload authorization"
            ) from exc

        upload_url = (
            f"https://{account_name}.blob.core.windows.net/{container_name}/{blob_name}?{sas_token}"
        )
        return UploadAuthorizationResult(
            upload_url=upload_url,
            expires_at=expires_at,
            required_headers={
                **UPLOAD_REQUIRED_HEADERS,
                "Content-Type": content_type,
            },
        )

    async def get_blob_metadata(self, blob_name: str) -> BlobMetadata | None:
        _, container_name = self._validate_configuration()
        client = await self._get_client()
        blob_client = client.get_blob_client(container=container_name, blob=blob_name)
        try:
            properties = await blob_client.get_blob_properties()
        except HttpResponseError as exc:
            if exc.status_code == 404:
                return None
            raise ProgressPhotoStorageError("Failed to read blob metadata") from exc
        except AzureError as exc:
            raise ProgressPhotoStorageUnavailableError("Azure storage unavailable") from exc

        return BlobMetadata(
            content_type=properties.content_settings.content_type or "",
            size_bytes=properties.size,
        )

    async def create_read_authorization(
        self,
        *,
        blob_name: str,
        expires_at: datetime,
    ) -> ReadAuthorizationResult:
        account_name, container_name = self._validate_configuration()
        client = await self._get_client()
        start = datetime.now(UTC) - timedelta(minutes=5)
        try:
            delegation_key = await self._user_delegation_key(client, start, expires_at)
            sas_token = generate_blob_sas(
                account_name=account_name,
                container_name=container_name,
                blob_name=blob_name,
                user_delegation_key=delegation_key,
                permission=BlobSasPermissions(read=True),
                expiry=expires_at,
                start=start,
                protocol="https",
            )
        except ProgressPhotoStorageError:
            raise
        except AzureError as exc:
            raise ProgressPhotoStorageAuthorizationError(
                "Failed to generate read authorization"
            ) from exc

        access_url = (
            f"https://{account_name}.blob.core.windows.net/{container_name}/{blob_name}?{sas_token}"
        )
        return ReadAuthorizationResult(access_url=access_url, expires_at=expires_at)

    async def delete_blob(self, blob_name: str) -> None:
        _, container_name = self._validate_configuration()
        client = await self._get_client()
        blob_client = client.get_blob_client(container=container_name, blob=blob_name)
        try:
            await blob_client.delete_blob()
        except HttpResponseError as exc:
            if exc.status_code == 404:
                return
            raise ProgressPhotoStorageError("Failed to delete blob") from exc
        except AzureError as exc:
            raise ProgressPhotoStorageUnavailableError("Azure storage unavailable") from exc


def build_blob_name(user_id: uuid.UUID, photo_id: uuid.UUID, content_type: str) -> str:
    extension = ALLOWED_CONTENT_TYPES[content_type]
    random_part = uuid.uuid4()
    return f"users/{user_id}/progress-photos/{photo_id}/{random_part}.{extension}"


def validate_content_type(content_type: str) -> None:
    normalized = content_type.strip().lower()
    if normalized in REJECTED_CONTENT_TYPES or normalized not in ALLOWED_CONTENT_TYPES:
        raise ValueError("Unsupported content type")


def validate_size_bytes(size_bytes: int) -> None:
    if size_bytes <= 0:
        raise ValueError("size_bytes must be greater than zero")
    if size_bytes > settings.progress_photo_max_bytes:
        raise ValueError("size_bytes exceeds maximum allowed size")


_fake_storage_instance: FakeProgressPhotoStorage | None = None


def get_progress_photo_storage() -> ProgressPhotoStorage:
    """FastAPI dependency that selects the storage provider from configuration."""
    global _fake_storage_instance
    if settings.progress_photo_storage_provider == "azure":
        return AzureBlobProgressPhotoStorage()
    if _fake_storage_instance is None:
        _fake_storage_instance = FakeProgressPhotoStorage()
    return _fake_storage_instance
