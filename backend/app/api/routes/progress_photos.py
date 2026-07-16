from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_session
from app.models.user import User
from app.schemas.progress_photo import (
    ProgressPhotoAccess,
    ProgressPhotoRead,
    ProgressPhotoUploadAuthorization,
    ProgressPhotoUploadRequest,
)
from app.services import progress_photo_service
from app.services.progress_photo_storage import (
    ProgressPhotoStorage,
    ProgressPhotoStorageAuthorizationError,
    ProgressPhotoStorageError,
    ProgressPhotoStorageNotConfiguredError,
    ProgressPhotoStorageUnavailableError,
    get_progress_photo_storage,
)

router = APIRouter(prefix="/progress-photos", tags=["progress-photos"])


@router.post("/upload-requests", response_model=ProgressPhotoUploadAuthorization, status_code=201)
async def create_upload_request(
    data: ProgressPhotoUploadRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    storage: ProgressPhotoStorage = Depends(get_progress_photo_storage),
) -> ProgressPhotoUploadAuthorization:
    try:
        return await progress_photo_service.create_upload_request(
            session, current_user, storage, data
        )
    except progress_photo_service.ProgressPhotoValidationError as exc:
        message = str(exc)
        if "content type" in message.lower():
            raise HTTPException(status_code=415, detail="Unsupported content type") from exc
        if "maximum" in message.lower():
            raise HTTPException(status_code=413, detail="File size exceeds maximum") from exc
        raise HTTPException(status_code=422, detail=message) from exc
    except ProgressPhotoStorageNotConfiguredError as exc:
        raise HTTPException(status_code=503, detail="Storage provider is not configured") from exc
    except ProgressPhotoStorageUnavailableError as exc:
        raise HTTPException(status_code=503, detail="Storage provider unavailable") from exc
    except ProgressPhotoStorageAuthorizationError as exc:
        raise HTTPException(status_code=502, detail="Storage authorization failed") from exc
    except ProgressPhotoStorageError as exc:
        raise HTTPException(status_code=502, detail="Storage operation failed") from exc


@router.post("/{photo_id}/confirm", response_model=ProgressPhotoRead)
async def confirm_upload(
    photo_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    storage: ProgressPhotoStorage = Depends(get_progress_photo_storage),
) -> ProgressPhotoRead:
    try:
        return await progress_photo_service.confirm_upload(session, current_user, storage, photo_id)
    except progress_photo_service.ProgressPhotoNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Progress photo not found") from exc
    except progress_photo_service.ProgressPhotoUploadExpiredError as exc:
        raise HTTPException(status_code=409, detail="Upload authorization expired") from exc
    except progress_photo_service.ProgressPhotoStateConflictError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except progress_photo_service.ProgressPhotoBlobMissingError as exc:
        raise HTTPException(status_code=409, detail="Uploaded blob not found") from exc
    except progress_photo_service.ProgressPhotoBlobMismatchError as exc:
        raise HTTPException(
            status_code=409, detail="Uploaded blob does not match authorization"
        ) from exc
    except ProgressPhotoStorageNotConfiguredError as exc:
        raise HTTPException(status_code=503, detail="Storage provider is not configured") from exc
    except ProgressPhotoStorageUnavailableError as exc:
        raise HTTPException(status_code=503, detail="Storage provider unavailable") from exc
    except ProgressPhotoStorageError as exc:
        raise HTTPException(status_code=502, detail="Storage operation failed") from exc


@router.get("", response_model=list[ProgressPhotoRead])
async def list_progress_photos(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[ProgressPhotoRead]:
    return await progress_photo_service.list_active_photos(session, current_user.id)


@router.post("/{photo_id}/access", response_model=ProgressPhotoAccess)
async def create_access_url(
    photo_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    storage: ProgressPhotoStorage = Depends(get_progress_photo_storage),
) -> ProgressPhotoAccess:
    try:
        return await progress_photo_service.create_access_url(
            session, current_user, storage, photo_id
        )
    except progress_photo_service.ProgressPhotoNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Progress photo not found") from exc
    except ProgressPhotoStorageNotConfiguredError as exc:
        raise HTTPException(status_code=503, detail="Storage provider is not configured") from exc
    except ProgressPhotoStorageUnavailableError as exc:
        raise HTTPException(status_code=503, detail="Storage provider unavailable") from exc
    except ProgressPhotoStorageAuthorizationError as exc:
        raise HTTPException(status_code=502, detail="Storage authorization failed") from exc
    except ProgressPhotoStorageError as exc:
        raise HTTPException(status_code=502, detail="Storage operation failed") from exc
