import asyncio
import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from sqlalchemy import text
from app.core.database import async_session_maker

async def clean_clinics():
    async with async_session_maker() as db:
        # Delete unused clinics
        await db.execute(text("DELETE FROM doctors WHERE clinic_id IN (1,2)"))
        await db.execute(text("DELETE FROM subscriptions WHERE clinic_id IN (1,2)"))
        await db.execute(text("DELETE FROM clinics WHERE user_id IN (8,9)"))
        await db.execute(text("DELETE FROM users WHERE id IN (8,9)"))
        await db.execute(text("UPDATE users SET avatar_url = 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=500&auto=format&fit=crop&q=60' WHERE email = 'basic_clinic_2@saludnow.com'"))
        await db.execute(text("UPDATE users SET avatar_url = 'https://images.unsplash.com/photo-1581594693702-fbdc51b2763b?w=500&auto=format&fit=crop&q=60' WHERE email = 'vip_clinic_2@saludnow.com'"))
        await db.commit()

if __name__ == "__main__":
    asyncio.run(clean_clinics())
