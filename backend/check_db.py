import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

async def test():
    engine = create_async_engine('postgresql+asyncpg://postgres:QubEALBqYtAClfTqFymJbMngiRjFstbM@junction.proxy.rlwy.net:47596/railway')
    async with engine.begin() as conn:
        res = await conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'subscriptions'"))
        print([row[0] for row in res.fetchall()])

asyncio.run(test())
