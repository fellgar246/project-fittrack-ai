from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class EmailAlreadyRegisteredError(Exception):
    pass


async def get_user(session: AsyncSession, user_id: UUID) -> User | None:
    return await session.get(User, user_id)
