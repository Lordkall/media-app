import asyncio
from sqlalchemy import text
from app.core.database import async_session_maker

async def add_cols():
    async with async_session_maker() as db:
        try:
            await db.execute(text("ALTER TABLE subscriptions ADD COLUMN reference_number VARCHAR;"))
        except Exception as e: print(e)
        try:
            await db.execute(text("ALTER TABLE subscriptions ADD COLUMN screenshot_base64 TEXT;"))
        except Exception as e: print(e)
        try:
            await db.execute(text("ALTER TABLE subscriptions ADD COLUMN amount_bs FLOAT;"))
        except Exception as e: print(e)
        await db.commit()
        print('Columns added!')

if __name__ == '__main__':
    asyncio.run(add_cols())
