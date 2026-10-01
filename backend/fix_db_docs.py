import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

engine = create_async_engine('postgresql+asyncpg://postgres:12345@127.0.0.1:5432/postgres')

async def fix():
    async with engine.begin() as conn:
        print("Running alter tables...")
        await conn.execute(text("ALTER TABLE doctors ADD COLUMN IF NOT EXISTS requested_clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL;"))
        await conn.execute(text("ALTER TABLE doctors ADD COLUMN IF NOT EXISTS clinic_join_status VARCHAR(20);"))
        print("Done!")

asyncio.run(fix())
