from datetime import datetime, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.progress_photo import ProgressPhoto, ProgressPhotoStatus
from app.models.user import User
from app.schemas.progress_photo import (
    ProgressPhotoAccess,
    ProgressPhotoRead,
    ProgressPhotoUploadAuthorization,
    ProgressPhotoUploadRequest,
)
from app.services.progress_photo_storage import (
    ProgressPhotoStorage,
    build_blob_name,
    validate_content_type,
    validate_size_bytes,
)


class ProgressPhotoNotFoundError(Exception):
    """Raised when a photo does not exist for the authenticated user."""


class ProgressPhotoUploadExpiredError(Exception):
    """Raised when confirmation happens after upload authorization expired."""


class ProgressPhotoStateConflictError(Exception):
    """Raised when a photo cannot transition to the requested state."""


class ProgressPhotoBlobMissingError(Exception):
    """Raised when the blob was never uploaded."""


class ProgressPhotoBlobMismatchError(Exception):
    """Raised when uploaded blob metadata does not match authorization."""


class ProgressPhotoValidationError(Exception):
    """Raised when request validation fails before persistence."""


async def _get_owned_photo(
    session: AsyncSession, user_id: UUID, photo_id: UUID
) -> ProgressPhoto | None:
    result = await session.execute(
        select(ProgressPhoto).where(
            ProgressPhoto.id == photo_id,
            ProgressPhoto.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def create_upload_request(
    session: AsyncSession,
    user: User,
    storage: ProgressPhotoStorage,
    data: ProgressPhotoUploadRequest,
) -> ProgressPhotoUploadAuthorization:
    try:
        validate_content_type(data.content_type)
        validate_size_bytes(data.size_bytes)
    except ValueError as exc:
        raise ProgressPhotoValidationError(str(exc)) from exc

    expires_at = datetime.utcnow() + timedelta(seconds=settings.progress_photo_upload_ttl_seconds)
    photo = ProgressPhoto(
        user_id=user.id,
        blob_name="pending",
        captured_at=data.captured_at,
        content_type=data.content_type.strip().lower(),
        size_bytes=data.size_bytes,
        notes=data.notes,
        status=ProgressPhotoStatus.PENDING.value,
        upload_expires_at=expires_at,
    )
    session.add(photo)
    await session.flush()

    photo.blob_name = build_blob_name(user.id, photo.id, photo.content_type)

    try:
        authorization = await storage.create_upload_authorization(
            blob_name=photo.blob_name,
            content_type=photo.content_type,
            expires_at=expires_at,
        )
    except Exception:
        await session.rollback()
        raise

    await session.commit()
    await session.refresh(photo)

    return ProgressPhotoUploadAuthorization(
        photo_id=photo.id,
        upload_url=authorization.upload_url,
        expires_at=authorization.expires_at,
        required_headers=authorization.required_headers,
    )


async def confirm_upload(
    session: AsyncSession,
    user: User,
    storage: ProgressPhotoStorage,
    photo_id: UUID,
) -> ProgressPhotoRead:
    photo = await _get_owned_photo(session, user.id, photo_id)
    if photo is None:
        raise ProgressPhotoNotFoundError()

    if photo.status == ProgressPhotoStatus.ACTIVE.value:
        return ProgressPhotoRead.model_validate(photo)

    if photo.status == ProgressPhotoStatus.INVALID.value:
        raise ProgressPhotoStateConflictError("Photo upload is invalid")

    now = datetime.utcnow()
    if photo.upload_expires_at < now:
        raise ProgressPhotoUploadExpiredError()

    metadata = await storage.get_blob_metadata(photo.blob_name)
    if metadata is None:
        raise ProgressPhotoBlobMissingError()

    if (
        metadata.content_type.strip().lower() != photo.content_type
        or metadata.size_bytes != photo.size_bytes
    ):
        photo.status = ProgressPhotoStatus.INVALID.value
        await storage.delete_blob(photo.blob_name)
        await session.commit()
        raise ProgressPhotoBlobMismatchError()

    photo.status = ProgressPhotoStatus.ACTIVE.value
    photo.confirmed_at = now
    await session.commit()
    await session.refresh(photo)
    return ProgressPhotoRead.model_validate(photo)


async def list_active_photos(session: AsyncSession, user_id: UUID) -> list[ProgressPhotoRead]:
    result = await session.execute(
        select(ProgressPhoto)
        .where(
            ProgressPhoto.user_id == user_id,
            ProgressPhoto.status == ProgressPhotoStatus.ACTIVE.value,
        )
        .order_by(
            ProgressPhoto.captured_at.desc(),
            ProgressPhoto.created_at.desc(),
        )
    )
    return [ProgressPhotoRead.model_validate(photo) for photo in result.scalars().all()]


async def create_access_url(
    session: AsyncSession,
    user: User,
    storage: ProgressPhotoStorage,
    photo_id: UUID,
) -> ProgressPhotoAccess:
    photo = await _get_owned_photo(session, user.id, photo_id)
    if photo is None or photo.status != ProgressPhotoStatus.ACTIVE.value:
        raise ProgressPhotoNotFoundError()

    expires_at = datetime.utcnow() + timedelta(seconds=settings.progress_photo_read_ttl_seconds)
    authorization = await storage.create_read_authorization(
        blob_name=photo.blob_name,
        expires_at=expires_at,
    )
    return ProgressPhotoAccess(
        photo_id=photo.id,
        access_url=authorization.access_url,
        expires_at=authorization.expires_at,
    )
