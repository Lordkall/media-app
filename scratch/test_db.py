import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

async def test():
    engine = create_async_engine('postgresql+asyncpg://media_db_wy3o_user:FOselX3i2fMATLvPuw5T3kA8OV4zmDuU@dpg-dallji2jnfac73a09p10-a.oregon-postgres.render.com/media_db_wy3o')
    async with engine.begin() as conn:
        res = await conn.execute(text('SELECT * FROM users limit 1'))
        print(res.fetchall())

asyncio.run(test())
