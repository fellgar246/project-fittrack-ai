from datetime import date, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.weekly_summary import (
    WeeklyDataQuality,
    WeeklyNutrition,
    WeeklySummaryPeriod,
    WeeklySummaryResponse,
    WeeklySummaryUser,
)
from app.services import measurement_service, nutrition_log_service, workout_log_service

MIN_WORKOUT_LOGS = 1
MIN_NUTRITION_DAYS = 3
MIN_MEASUREMENTS = 1


async def get_weekly_summary(
    session: AsyncSession, user: User, week_start: date
) -> WeeklySummaryResponse:
    week_end = week_start + timedelta(days=6)

    workouts = await workout_log_service.get_summary(session, user.id, week_start, week_end)
    nutrition_raw = await nutrition_log_service.get_summary(
        session, user.id, week_start, week_end
    )
    measurements = await measurement_service.get_progress(
        session, user.id, week_start, week_end
    )

    nutrition = WeeklyNutrition(
        days_logged=nutrition_raw.days_logged,
        avg_calories=nutrition_raw.avg_calories if nutrition_raw.days_logged > 0 else None,
        avg_protein=nutrition_raw.avg_protein if nutrition_raw.days_logged > 0 else None,
        avg_carbs=nutrition_raw.avg_carbs if nutrition_raw.days_logged > 0 else None,
        avg_fats=nutrition_raw.avg_fats if nutrition_raw.days_logged > 0 else None,
        total_calories=nutrition_raw.total_calories,
        total_protein=nutrition_raw.total_protein,
        total_carbs=nutrition_raw.total_carbs,
        total_fats=nutrition_raw.total_fats,
    )

    missing_data = []
    if workouts.total_logs < MIN_WORKOUT_LOGS:
        missing_data.append("workout_logs")
    if nutrition.days_logged < MIN_NUTRITION_DAYS:
        missing_data.append("nutrition_logs")
    if measurements.measurements_count < MIN_MEASUREMENTS:
        missing_data.append("body_measurements")

    data_quality = WeeklyDataQuality(
        has_workout_data=workouts.total_logs > 0,
        has_nutrition_data=nutrition.days_logged > 0,
        has_measurement_data=measurements.measurements_count > 0,
        nutrition_days_logged=nutrition.days_logged,
        measurement_entries=measurements.measurements_count,
        is_ready_for_ai_recommendation=len(missing_data) == 0,
        missing_data=missing_data,
    )

    return WeeklySummaryResponse(
        user=WeeklySummaryUser(id=user.id, name=user.name, goal=user.goal),
        period=WeeklySummaryPeriod(week_start=week_start, week_end=week_end),
        workouts=workouts,
        nutrition=nutrition,
        measurements=measurements,
        data_quality=data_quality,
    )
