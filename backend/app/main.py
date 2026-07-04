from fastapi import FastAPI

from app.api.routes import auth, health, users, workout_plans
from app.core.config import settings

app = FastAPI(title=settings.app_name, version=settings.version)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(workout_plans.router)
