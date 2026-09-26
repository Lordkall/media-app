import asyncio
from sqlalchemy import select
from app.core.database import async_session_maker
from app.models.notifications import Notification

async def check():
    async with async_session_maker() as db:
        res = await db.scalars(select(Notification).order_by(Notification.id.desc()).limit(5))
        for n in res:
            print(f"ID: {n.id}, URL: {n.action_url}")

if __name__ == '__main__':
    asyncio.run(check())
