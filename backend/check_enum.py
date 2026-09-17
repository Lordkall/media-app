import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

async def main():
    engine = create_async_engine("postgresql+asyncpg://postgres:12345@127.0.0.1:5432/postgres")
    async with engine.connect() as conn:
        res = await conn.execute(text("SELECT unnest(enum_range(NULL::notificationtype))"))
        print([r[0] for r in res.fetchall()])

asyncio.run(main())
