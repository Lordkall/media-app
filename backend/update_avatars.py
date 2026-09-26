import asyncio
import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from sqlalchemy import select, update
from app.core.database import async_session_maker
from app.models.users import User
from app.models.doctors import Doctor
from app.models.clinics import Clinic
from app.models.notifications import Notification

async def update_avatars():
    async with async_session_maker() as db:
        res = await db.execute(select(Doctor).where(Doctor.clinic_id.isnot(None)))
        doctors = res.scalars().all()
        
        avatars = [
            'https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=500&auto=format&fit=crop&q=60',
            'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=500&auto=format&fit=crop&q=60',
            'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=500&auto=format&fit=crop&q=60',
            'https://images.unsplash.com/photo-1594824432258-f99cc2f37c35?w=500&auto=format&fit=crop&q=60',
            'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=500&auto=format&fit=crop&q=60',
            'https://images.unsplash.com/photo-1622902046580-2b47f47f5471?w=500&auto=format&fit=crop&q=60'
        ]
        
        for i, doc in enumerate(doctors):
            await db.execute(
                update(User).where(User.id == doc.user_id)
                .values(avatar_url=avatars[i % len(avatars)])
            )
        await db.commit()
        print("Updated avatars for doctors")

if __name__ == "__main__":
    asyncio.run(update_avatars())
