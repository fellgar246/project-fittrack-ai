from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.schemas.user import UserRead
from app.services import user_service

router = APIRouter()


@router.get("/users/{user_id}", response_model=UserRead)
async def get_user(
    user_id: UUID, session: AsyncSession = Depends(get_session)
) -> UserRead:
    user = await user_service.get_user(session, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user
