from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ProgressPhotoUploadRequest(BaseModel):
    captured_at: date
    content_type: str
    size_bytes: int = Field(gt=0)
    notes: str | None = Field(default=None, max_length=2000)


class ProgressPhotoUploadAuthorization(BaseModel):
    photo_id: UUID
    upload_url: str
    expires_at: datetime
    required_headers: dict[str, str]


class ProgressPhotoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    captured_at: date
    content_type: str
    size_bytes: int
    notes: str | None
    status: str
    created_at: datetime
    confirmed_at: datetime | None


class ProgressPhotoAccess(BaseModel):
    photo_id: UUID
    access_url: str
    expires_at: datetime
