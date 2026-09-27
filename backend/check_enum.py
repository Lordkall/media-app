import asyncio
from sqlalchemy import text
from app.core.database import async_session_maker
from app.models.notifications import NotificationType

async def fix():
    async with async_session_maker() as db:
        res = await db.execute(text("SELECT enumlabel FROM pg_enum JOIN pg_type ON pg_enum.enumtypid = pg_type.oid WHERE pg_type.typname = 'notificationtype';"))
        labels = [r[0] for r in res.fetchall()]
        
        for e in NotificationType:
            if e.value not in labels:
                print(f'Adding {e.value}')
                try:
                    await db.execute(text(f"ALTER TYPE notificationtype ADD VALUE '{e.value}';"))
                    await db.commit()
                except Exception as ex:
                    print('error:', ex)
                    await db.rollback()

asyncio.run(fix())
