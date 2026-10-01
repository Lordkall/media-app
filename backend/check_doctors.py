import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy import select
from app.models.doctors import Doctor

engine = create_async_engine('postgresql+asyncpg://postgres:12345@127.0.0.1:5432/postgres')

async def test():
    async with AsyncSession(engine) as db:
        docs = (await db.scalars(select(Doctor))).all()
        print([(d.id, d.clinic_id, d.clinic_join_status) for d in docs])

asyncio.run(test())
