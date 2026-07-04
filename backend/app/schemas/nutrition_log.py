from datetime import date
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class NutritionLogCreate(BaseModel):
    date: date
    calories: int = Field(ge=0)
    protein: float = Field(ge=0)
    carbs: float = Field(ge=0)
    fats: float = Field(ge=0)
    notes: str | None = None


class NutritionLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    date: date
    calories: int
    protein: float
    carbs: float
    fats: float
    notes: str | None


class NutritionLogSummary(BaseModel):
    days_logged: int
    avg_calories: float
    avg_protein: float
    avg_carbs: float
    avg_fats: float
    total_calories: int
    total_protein: float
    total_carbs: float
    total_fats: float
