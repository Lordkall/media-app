import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

async def run():
    engine = create_async_engine('postgresql+asyncpg://postgres:postgres@localhost:5432/saludnow')
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TYPE notificationtype ADD VALUE 'SUPPORT_MESSAGE'"))
        except Exception as e:
            print("Error or already added:", e)

if __name__ == '__main__':
    asyncio.run(run())
