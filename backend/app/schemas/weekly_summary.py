from datetime import date
from uuid import UUID

from pydantic import BaseModel

from app.schemas.measurement import BodyMeasurementProgress
from app.schemas.workout_log import WorkoutLogSummary


class WeeklySummaryUser(BaseModel):
    id: UUID
    name: str
    goal: str


class WeeklySummaryPeriod(BaseModel):
    week_start: date
    week_end: date


class WeeklyNutrition(BaseModel):
    days_logged: int
    avg_calories: float | None
    avg_protein: float | None
    avg_carbs: float | None
    avg_fats: float | None
    total_calories: int
    total_protein: float
    total_carbs: float
    total_fats: float


class WeeklyDataQuality(BaseModel):
    has_workout_data: bool
    has_nutrition_data: bool
    has_measurement_data: bool
    nutrition_days_logged: int
    measurement_entries: int
    is_ready_for_ai_recommendation: bool
    missing_data: list[str]


class WeeklySummaryResponse(BaseModel):
    user: WeeklySummaryUser
    period: WeeklySummaryPeriod
    workouts: WorkoutLogSummary
    nutrition: WeeklyNutrition
    measurements: BodyMeasurementProgress
    data_quality: WeeklyDataQuality
