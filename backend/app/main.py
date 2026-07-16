from fastapi import FastAPI

from app.api.routes import (
    auth,
    health,
    measurements,
    nutrition_logs,
    progress_photos,
    recommendations,
    users,
    weekly_summary,
    workout_logs,
    workout_plans,
)
from app.core.config import settings

app = FastAPI(title=settings.app_name, version=settings.version)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(workout_plans.router)
app.include_router(workout_logs.router)
app.include_router(nutrition_logs.router)
app.include_router(measurements.router)
app.include_router(weekly_summary.router)
app.include_router(recommendations.router)
app.include_router(progress_photos.router)
