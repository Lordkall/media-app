from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.users import User
from app.models.doctors import Doctor, Availability
from app.models.appointments import Appointment, AppointmentStatus
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.schemas.doctors import DoctorResponse, DoctorUpdate
from app.schemas.availability import AvailabilityUpdate
from app.api.v1.endpoints.users import get_current_user
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

router = APIRouter()

@router.get("/me", response_model=DoctorResponse)
async def read_doctor_me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role.value != "doctor":
        raise HTTPException(status_code=403, detail="User is not a doctor")
        
    query = select(Doctor).where(Doctor.user_id == current_user.id)
    result = await db.execute(query)
    doc = result.scalars().first()
    
    if not doc:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
        
    # Check if doctor is VIP (sponsored)
    sub_query = select(Subscription).where(
        Subscription.doctor_id == doc.id,
        Subscription.status == SubscriptionStatus.ACTIVE,
        Subscription.plan == SubscriptionPlan.SPONSORED
    )
    sub_result = await db.execute(sub_query)
    sub = sub_result.scalars().first()
    
    doc.is_vip = sub is not None
    
    return doc

@router.put("/me", response_model=DoctorResponse)
async def update_doctor_me(
    doc_in: DoctorUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role.value != "doctor":
        raise HTTPException(status_code=403, detail="User is not a doctor")
        
    query = select(Doctor).where(Doctor.user_id == current_user.id)
    result = await db.execute(query)
    doc = result.scalars().first()
    
    if not doc:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
        
    update_data = doc_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(doc, field, value)
        if field == "specialties":
            from sqlalchemy.orm.attributes import flag_modified
            flag_modified(doc, "specialties")
        
    db.add(doc)
    await db.commit()
    await db.refresh(doc)
    
    active_vip = await db.scalar(
        select(Subscription.id).where(
            Subscription.doctor_id == doc.id,
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.plan == SubscriptionPlan.SPONSORED,
        )
    )
    doc.is_vip = active_vip is not None
    return doc

@router.get("/{doctor_id}/availability")
async def get_doctor_availability(
    doctor_id: int,
    db: AsyncSession = Depends(get_db)
):
    query = select(Availability).where(Availability.doctor_id == doctor_id)
    result = await db.execute(query)
    availabilities = result.scalars().all()
    
    out = []
    for a in availabilities:
        booked_query = select(Appointment.turn_number).where(
            Appointment.doctor_id == doctor_id,
            Appointment.appointment_date == a.date,
            Appointment.status != AppointmentStatus.CANCELLED
        )
        booked_result = await db.execute(booked_query)
        booked_turns = set(booked_result.scalars().all())

        start_hour, start_minute = map(int, a.start_time[:5].split(":"))
        end_hour, end_minute = map(int, a.end_time[:5].split(":"))
        start_minutes = start_hour * 60 + start_minute
        end_minutes = end_hour * 60 + end_minute
        now = datetime.now(ZoneInfo("America/Caracas"))
        is_today = a.date == now.date()
        current_minutes = now.hour * 60 + now.minute
        slots = []
        for offset in range(0, max(0, end_minutes - start_minutes), 30):
            turn_number = offset // 30 + 1
            slot_minutes = start_minutes + offset
            slot_time = (datetime.min + timedelta(minutes=slot_minutes)).strftime("%I:%M %p")
            slots.append({
                "turn_number": turn_number,
                "time_block": slot_time,
                "available": turn_number not in booked_turns
                and (not is_today or slot_minutes > current_minutes),
            })

        out.append({
            "id": a.id,
            "date": a.date.isoformat(),
            "start_time": a.start_time,
            "end_time": a.end_time,
            "slots": slots,
            "is_full": not any(slot["available"] for slot in slots)
        })
    return out

@router.post("/me/availability")
async def update_doctor_availability(
    data: AvailabilityUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role.value != "doctor":
        raise HTTPException(status_code=403, detail="User is not a doctor")
        
    query = select(Doctor).where(Doctor.user_id == current_user.id)
    result = await db.execute(query)
    doc = result.scalars().first()
    
    if not doc:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
        
    # Delete existing availability
    from sqlalchemy import delete
    await db.execute(delete(Availability).where(Availability.doctor_id == doc.id))
    
    # Add new availability
    for a in data.availabilities:
        new_avail = Availability(
            doctor_id=doc.id,
            date=datetime.strptime(a.date, "%Y-%m-%d").date(),
            start_time=a.start_time,
            end_time=a.end_time
        )
        db.add(new_avail)
        
    await db.commit()
    return {"message": "Disponibilidad actualizada"}
