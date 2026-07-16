import enum
import uuid
from datetime import date, datetime

from sqlalchemy import BigInteger, Date, ForeignKey, Index, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ProgressPhotoStatus(str, enum.Enum):
    PENDING = "pending"
    ACTIVE = "active"
    INVALID = "invalid"


class ProgressPhoto(Base):
    __tablename__ = "progress_photos"
    __table_args__ = (
        Index("ix_progress_photos_user_captured_at", "user_id", "captured_at"),
        Index("ix_progress_photos_user_created_at", "user_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    blob_name: Mapped[str] = mapped_column(String(512), nullable=False, unique=True)
    captured_at: Mapped[date] = mapped_column(Date, nullable=False)
    content_type: Mapped[str] = mapped_column(String(64), nullable=False)
    size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default=ProgressPhotoStatus.PENDING.value
    )
    upload_expires_at: Mapped[datetime] = mapped_column(nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), onupdate=func.now())
    confirmed_at: Mapped[datetime | None] = mapped_column(nullable=True)
