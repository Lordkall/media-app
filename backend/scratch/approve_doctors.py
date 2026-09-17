import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

async def main():
    engine = create_async_engine("postgresql+asyncpg://postgres:12345@127.0.0.1:5432/postgres")
    async with engine.begin() as conn:
        await conn.execute(text("UPDATE doctors SET is_approved = true"))
    print("Todos los doctores actuales fueron aprobados.")

asyncio.run(main())
