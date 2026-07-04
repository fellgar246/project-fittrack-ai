from datetime import date
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class BodyMeasurementCreate(BaseModel):
    date: date
    weight: float = Field(gt=0)
    waist: float | None = Field(default=None, gt=0)
    body_fat_estimate: float | None = Field(default=None, ge=1, le=80)
    notes: str | None = None


class BodyMeasurementRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    date: date
    weight: float
    waist: float | None
    body_fat_estimate: float | None
    notes: str | None


class BodyMeasurementProgress(BaseModel):
    measurements_count: int
    start_date: date | None = None
    end_date: date | None = None
    start_weight: float | None = None
    end_weight: float | None = None
    weight_change: float | None = None
    start_waist: float | None = None
    end_waist: float | None = None
    waist_change: float | None = None
    start_body_fat_estimate: float | None = None
    end_body_fat_estimate: float | None = None
    body_fat_change: float | None = None
