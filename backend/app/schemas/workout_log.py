from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class WorkoutLogCreate(BaseModel):
    exercise_id: UUID
    performed_at: datetime
    sets: int = Field(gt=0)
    reps: int = Field(gt=0)
    weight: float | None = Field(default=None, ge=0)
    notes: str | None = None


class WorkoutLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    exercise_id: UUID
    exercise_name: str
    performed_at: datetime
    sets: int
    reps: int
    weight: float | None
    notes: str | None


class WorkoutLogSummary(BaseModel):
    total_logs: int
    total_sets: int
    total_reps: int
    unique_exercises: int
    workout_days: int
