import asyncio
from sqlalchemy import select, update
from app.core.database import async_session_maker
from app.models.appointments import Appointment
from app.models.patients import Patient

async def main():
    async with async_session_maker() as db:
        pat_query = select(Patient).where(Patient.user_id == 7)
        pat = (await db.execute(pat_query)).scalar_one_or_none()
        if not pat:
            print("Patient not found")
            return
            
        print("Reassigning appointments to patient_id:", pat.id)
        # Update all appointments that currently have patient_id = 1 (dummy) to pat.id
        await db.execute(update(Appointment).where(Appointment.patient_id == 1).values(patient_id=pat.id))
        await db.commit()
        print("Done")

if __name__ == '__main__':
    asyncio.run(main())
