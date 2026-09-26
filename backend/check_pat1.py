import asyncio
from sqlalchemy import select
from app.core.database import async_session_maker
from app.models.patients import Patient
from app.models.users import User

async def main():
    async with async_session_maker() as db:
        query = select(Patient).where(Patient.id == 1)
        result = await db.execute(query)
        pat = result.scalar_one_or_none()
        if pat:
            print('Patient 1 user_id:', pat.user_id)

if __name__ == '__main__':
    asyncio.run(main())
