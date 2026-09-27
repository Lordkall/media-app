import asyncio
from sqlalchemy import select, delete, asc
from app.core.database import async_session_maker
from app.models.users import User, RoleEnum
from app.models.doctors import Doctor
from app.models.patients import Patient
from app.models.clinics import Clinic
from app.models.appointments import Appointment
from app.models.subscriptions import Subscription

async def cleanup():
    async with async_session_maker() as db:
        admin = (await db.execute(select(User).where(User.role == RoleEnum.ADMIN).order_by(asc(User.id)))).scalars().first()
        doctor = (await db.execute(select(User).where(User.role == RoleEnum.DOCTOR).order_by(asc(User.id)))).scalars().first()
        patient = (await db.execute(select(User).where(User.role == RoleEnum.PATIENT).order_by(asc(User.id)))).scalars().first()
        clinic = (await db.execute(select(User).where(User.role == RoleEnum.CLINIC).order_by(asc(User.id)))).scalars().first()
        
        keep_ids = [u.id for u in [admin, doctor, patient, clinic] if u]
        print('Keeping user ids:', keep_ids)
        
        if keep_ids:
            doc_ids = [doc.id for doc in (await db.execute(select(Doctor).where(Doctor.user_id.in_(keep_ids)))).scalars()]
            pat_ids = [pat.id for pat in (await db.execute(select(Patient).where(Patient.user_id.in_(keep_ids)))).scalars()]
            cli_ids = [cli.id for cli in (await db.execute(select(Clinic).where(Clinic.user_id.in_(keep_ids)))).scalars()]
            
            # Delete appointments
            if pat_ids and doc_ids:
                await db.execute(delete(Appointment).where(~Appointment.patient_id.in_(pat_ids) | ~Appointment.doctor_id.in_(doc_ids)))
            
            # Delete subscriptions
            await db.execute(delete(Subscription).where(
                (Subscription.doctor_id.isnot(None) & ~Subscription.doctor_id.in_(doc_ids)) | 
                (Subscription.clinic_id.isnot(None) & ~Subscription.clinic_id.in_(cli_ids))
            ))
            
            # Delete docs, pats, clis
            await db.execute(delete(Doctor).where(~Doctor.user_id.in_(keep_ids)))
            await db.execute(delete(Patient).where(~Patient.user_id.in_(keep_ids)))
            await db.execute(delete(Clinic).where(~Clinic.user_id.in_(keep_ids)))
            
            # Finally users
            await db.execute(delete(User).where(~User.id.in_(keep_ids)))
            await db.commit()
            print('Cleanup complete')

asyncio.run(cleanup())
