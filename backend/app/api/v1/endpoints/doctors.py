from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.users import User
from app.models.doctors import Doctor, Availability
from app.models.appointments import Appointment
from sqlalchemy import func
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.schemas.doctors import DoctorResponse, DoctorUpdate
from app.schemas.availability import AvailabilityUpdate
from app.api.v1.endpoints.users import get_current_user
from datetime import datetime

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
    
    doc.is_vip = False # Temporarily assume false on update, since the UI usually only reads this on get
    return doc

@router.get("/{doctor_id}/availability")
async def get_doctor_availability(
    doctor_id: int,
    db: AsyncSession = Depends(get_db)
):
    query = select(Availability).where(Availability.doctor_id == doctor_id)
    result = await db.execute(query)
    availabilities = result.scalars().all()
    
    # Need doctor max_patients to calculate fullness
    doc_query = select(Doctor).where(Doctor.id == doctor_id)
    doc_result = await db.execute(doc_query)
    doc = doc_result.scalars().first()
    max_p = doc.max_patients_per_day if doc else 999
    
    out = []
    for a in availabilities:
        # Check how many appointments are on this date
        app_count_query = select(func.count(Appointment.id)).where(
            Appointment.doctor_id == doctor_id,
            Appointment.appointment_date == a.date,
            Appointment.status == "scheduled" # Only count active appointments
        )
        app_result = await db.execute(app_count_query)
        count = app_result.scalar() or 0
        
        out.append({
            "id": a.id,
            "date": a.date.isoformat(),
            "start_time": a.start_time,
            "end_time": a.end_time,
            "is_full": count >= max_p
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
