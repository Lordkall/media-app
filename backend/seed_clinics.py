import asyncio
import sys
import os

# Add backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import select
from app.core.database import async_session_maker
from app.models.users import User, RoleEnum
from app.models.clinics import Clinic
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription, SubscriptionPlan, SubscriptionStatus
from app.core.security import get_password_hash
from datetime import datetime, timedelta

async def seed_clinics():
    async with async_session_maker() as db:
        # Create Clinic 1 (Basic)
        c1_email = "basic_clinic_2@saludnow.com"
        result = await db.execute(select(User).where(User.email == c1_email))
        if not result.scalar_one_or_none():
            user1 = User(
                first_name="Clínica Básica",
                last_name="",
                email=c1_email,
                phone="04141234567",
                state="Distrito Capital",
                address="Av. Principal de la Clínica Básica, Caracas",
                role=RoleEnum.CLINIC,
                hashed_password=get_password_hash("123456")
            )
            db.add(user1)
            await db.commit()
            await db.refresh(user1)

            clinic1 = Clinic(
                user_id=user1.id,
                description="Clínica con plan básico, atención general y de calidad.",
                is_approved=True
            )
            db.add(clinic1)
            await db.commit()
            await db.refresh(clinic1)

            sub1 = Subscription(
                clinic_id=clinic1.id,
                plan=SubscriptionPlan.CLINIC_BASIC,
                status=SubscriptionStatus.ACTIVE,
                start_date=datetime.utcnow(),
                end_date=datetime.utcnow() + timedelta(days=30),
                grace_end_date=datetime.utcnow() + timedelta(days=35)
            )
            db.add(sub1)
            await db.commit()
            
            # Create 7 doctors for this clinic
            for i in range(1, 8):
                d_email = f"doc_basic_2_{i}@saludnow.com"
                du = User(
                    first_name=f"Doctor",
                    last_name=f"Básico {i}",
                    email=d_email,
                    phone="04120000000",
                    state="Distrito Capital",
                    address="Av. Principal de la Clínica Básica, Caracas",
                    role=RoleEnum.DOCTOR,
                    hashed_password=get_password_hash("123456")
                )
                db.add(du)
                await db.commit()
                await db.refresh(du)
                
                doc = Doctor(
                    user_id=du.id,
                    specialties=["Medicina General", "Cardiología"],
                    consultation_fee=30.0,
                    is_sponsored=False,
                    clinic_id=clinic1.id
                )
                db.add(doc)
            await db.commit()
            print("Created basic clinic with 7 doctors.")

        # Create Clinic 2 (VIP)
        c2_email = "vip_clinic_2@saludnow.com"
        result = await db.execute(select(User).where(User.email == c2_email))
        if not result.scalar_one_or_none():
            user2 = User(
                first_name="Clínica VIP",
                last_name="",
                email=c2_email,
                phone="04147654321",
                state="Miranda",
                address="Av. VIP, Torre Médica Premium, Miranda",
                role=RoleEnum.CLINIC,
                hashed_password=get_password_hash("123456")
            )
            db.add(user2)
            await db.commit()
            await db.refresh(user2)

            clinic2 = Clinic(
                user_id=user2.id,
                description="Centro médico premium con las mejores instalaciones y 15 especialistas a su disposición.",
                is_approved=True
            )
            db.add(clinic2)
            await db.commit()
            await db.refresh(clinic2)

            sub2 = Subscription(
                clinic_id=clinic2.id,
                plan=SubscriptionPlan.CLINIC_VIP,
                status=SubscriptionStatus.ACTIVE,
                start_date=datetime.utcnow(),
                end_date=datetime.utcnow() + timedelta(days=30),
                grace_end_date=datetime.utcnow() + timedelta(days=35)
            )
            db.add(sub2)
            await db.commit()
            
            # Create 15 doctors for this clinic
            for i in range(1, 16):
                d_email = f"doc_vip_2_{i}@saludnow.com"
                du = User(
                    first_name=f"Especialista",
                    last_name=f"VIP {i}",
                    email=d_email,
                    phone="04240000000",
                    state="Miranda",
                    address="Av. VIP, Torre Médica Premium, Miranda",
                    role=RoleEnum.DOCTOR,
                    hashed_password=get_password_hash("123456")
                )
                db.add(du)
                await db.commit()
                await db.refresh(du)
                
                doc = Doctor(
                    user_id=du.id,
                    specialties=["Neurología", "Cirugía General", "Traumatología"],
                    consultation_fee=80.0,
                    is_sponsored=True,
                    clinic_id=clinic2.id
                )
                db.add(doc)
            await db.commit()
            print("Created VIP clinic with 15 doctors.")

if __name__ == "__main__":
    asyncio.run(seed_clinics())
