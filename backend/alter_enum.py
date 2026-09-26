import asyncio
from sqlalchemy import text
from app.core.database import async_session_maker

async def main():
    async with async_session_maker() as db:
        await db.execute(text("ALTER TYPE subscriptionplan ADD VALUE 'CLINIC_BASIC';"))
        await db.execute(text("ALTER TYPE subscriptionplan ADD VALUE 'CLINIC_VIP';"))
        await db.commit()

if __name__ == "__main__":
    asyncio.run(main())
