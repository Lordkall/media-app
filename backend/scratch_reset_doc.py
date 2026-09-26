import asyncio
from app.core.database import async_session_maker
from app.models.users import User
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription
from sqlalchemy import select, delete

async def reset_doc():
    async with async_session_maker() as db:
        user = await db.scalar(select(User).where(User.email=='doctor@saludnow.com'))
        if user:
            doc = await db.scalar(select(Doctor).where(Doctor.user_id==user.id))
            if doc:
                await db.execute(delete(Subscription).where(Subscription.doctor_id==doc.id))
                await db.commit()
                print('Done reset')
        else:
            print('User not found')

if __name__ == '__main__':
    asyncio.run(reset_doc())
