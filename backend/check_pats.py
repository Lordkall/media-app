import asyncio
from sqlalchemy import select
from app.core.database import async_session_maker
from app.models.patients import Patient
from app.models.users import User

async def main():
    async with async_session_maker() as db:
        res1 = await db.execute(select(User).where(User.role=='patient'))
        users = res1.scalars().all()
        print('Users:', [u.email for u in users])
        res2 = await db.execute(select(Patient))
        pats = res2.scalars().all()
        print('Patients:', [p.user_id for p in pats])

if __name__ == '__main__':
    asyncio.run(main())
