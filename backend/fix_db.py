import asyncio
from sqlalchemy import text
from app.core.database import async_session_maker

async def main():
    async with async_session_maker() as db:
        try:
            await db.execute(text("ALTER TYPE notificationtype ADD VALUE 'support_message';"))
            await db.commit()
            print("Added support_message")
        except Exception as e:
            print("Error or exists:", e)

if __name__ == "__main__":
    asyncio.run(main())
