import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, ForeignKey, Integer, Numeric, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class NutritionLog(Base):
    __tablename__ = "nutrition_logs"
    __table_args__ = (UniqueConstraint("user_id", "date", name="uq_nutrition_logs_user_date"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    calories: Mapped[int] = mapped_column(Integer, nullable=False)
    protein: Mapped[Decimal] = mapped_column(Numeric(6, 2), nullable=False)
    carbs: Mapped[Decimal] = mapped_column(Numeric(6, 2), nullable=False)
    fats: Mapped[Decimal] = mapped_column(Numeric(6, 2), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(), onupdate=func.now()
    )
