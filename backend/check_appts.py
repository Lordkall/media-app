import asyncio
from sqlalchemy import select
from app.core.database import async_session_maker
from app.models.appointments import Appointment

async def main():
    async with async_session_maker() as db:
        query = select(Appointment)
        result = await db.execute(query)
        appointments = result.scalars().all()
        print('All Appointments:', [(a.id, a.patient_id, a.doctor_id, a.appointment_date) for a in appointments])

if __name__ == '__main__':
    asyncio.run(main())
