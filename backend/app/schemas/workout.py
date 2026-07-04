from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ExerciseCreate(BaseModel):
    name: str
    muscle_group: str
    target_sets: int = Field(gt=0)
    target_reps: str = Field(min_length=1)


class WorkoutDayCreate(BaseModel):
    day_of_week: int = Field(ge=1, le=7)
    title: str
    exercises: list[ExerciseCreate] = []


class WorkoutPlanCreate(BaseModel):
    name: str
    goal: str
    active: bool = True
    days: list[WorkoutDayCreate] = []


class WorkoutPlanSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    goal: str
    active: bool
    days_count: int
    exercises_count: int


class ExerciseRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    muscle_group: str
    target_sets: int
    target_reps: str


class WorkoutDayRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    day_of_week: int
    title: str
    exercises: list[ExerciseRead]


class WorkoutPlanDetail(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    goal: str
    active: bool
    days: list[WorkoutDayRead]
