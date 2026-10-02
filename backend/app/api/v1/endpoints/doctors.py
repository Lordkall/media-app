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
        booked_query = select(Appointment).where(
            Appointment.doctor_id == doctor_id,
            Appointment.appointment_date == a.date,
            Appointment.status != AppointmentStatus.CANCELLED
        )
        booked_result = await db.execute(booked_query)
        booked_appointments = booked_result.scalars().all()

        start_hour, start_minute = map(int, a.start_time[:5].split(":"))
        end_hour, end_minute = map(int, a.end_time[:5].split(":"))
        start_minutes = start_hour * 60 + start_minute
        end_minutes = end_hour * 60 + end_minute
        duration = a.slot_duration_minutes or 30
        if duration not in (30, 60, 120):
            duration = 30
        now = datetime.now(ZoneInfo("America/Caracas"))
        is_today = a.date == now.date()
        current_minutes = now.hour * 60 + now.minute
        slots = []
        for offset in range(0, max(0, end_minutes - start_minutes), duration):
            if offset + duration > end_minutes - start_minutes:
                continue
            turn_number = offset // duration + 1
            slot_minutes = start_minutes + offset
            slot_time = (datetime.min + timedelta(minutes=slot_minutes)).strftime("%I:%M %p")
            occupied = any(
                slot_minutes < (
                    booked.appointment_start_minutes
                    if booked.appointment_start_minutes is not None
                    else start_minutes + (booked.turn_number - 1) * 30
                ) + (booked.appointment_duration_minutes or 30)
                and (
                    booked.appointment_start_minutes
                    if booked.appointment_start_minutes is not None
                    else start_minutes + (booked.turn_number - 1) * 30
                ) < slot_minutes + duration
                for booked in booked_appointments
            )
            slots.append({
                "turn_number": turn_number,
                "time_block": slot_time,
                "available": not occupied
                and (not is_today or slot_minutes > current_minutes),
            })

        out.append({
            "id": a.id,
            "date": a.date.isoformat(),
            "start_time": a.start_time,
            "end_time": a.end_time,
            "slot_duration_minutes": duration,
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
    if current_user.role.value not in ["doctor", "assistant"]:
        raise HTTPException(status_code=403, detail="User is not a doctor")
        
    if current_user.role.value == "doctor":
        query = select(Doctor).where(Doctor.user_id == current_user.id).with_for_update()
    else:
        if not current_user.linked_doctor_id:
            raise HTTPException(status_code=403, detail="Asistente no vinculado a ningún doctor")
        query = select(Doctor).where(Doctor.id == current_user.linked_doctor_id).with_for_update()
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
            end_time=a.end_time,
            slot_duration_minutes=a.slot_duration_minutes,
        )
        db.add(new_avail)
        
    await db.commit()
    return {"message": "Disponibilidad actualizada"}

@router.get("/me/clinic-invitations")
async def get_clinic_invitations(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    if current_user.role.value != "doctor":
        raise HTTPException(status_code=403, detail="User is not a doctor")
        
    doc = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
    if not doc or not doc.requested_clinic_id or doc.clinic_join_status != "invited":
        return []
        
    from app.models.clinics import Clinic
    clinic = await db.get(Clinic, doc.requested_clinic_id)
    if not clinic:
        return []
        
    clinic_user = await db.get(User, clinic.user_id)
    
    return [{
        "clinic_id": clinic.id,
        "name": clinic_user.first_name,
        "address": clinic_user.address,
        "avatar_url": clinic_user.avatar_url
    }]

@router.post("/me/clinic-invitations/{clinic_id}/{action}")
async def resolve_clinic_invitation(
    clinic_id: int, action: str,
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    if current_user.role.value != "doctor":
        raise HTTPException(status_code=403, detail="Solo los doctores pueden responder invitaciones")
        
    doc = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id).with_for_update())
    if not doc or doc.requested_clinic_id != clinic_id or doc.clinic_join_status != "invited":
        raise HTTPException(status_code=404, detail="Invitación no encontrada")
        
    from app.models.clinics import Clinic
    clinic = await db.get(Clinic, clinic_id)
    
    if action == "accept":
        from app.core.clinic_access import active_clinic_subscription, clinic_has_capacity
        subscription = await active_clinic_subscription(db, clinic.id)
        if not subscription or not await clinic_has_capacity(db, clinic.id, subscription.plan):
            raise HTTPException(status_code=409, detail="La clínica ya no tiene capacidad o plan activo")
            
        doc.clinic_id = clinic.id
        doc.requested_clinic_id = None
        doc.clinic_join_status = "approved"
        
        from app.models.notifications import Notification, NotificationType
        prefix = "La Dra." if current_user.gender in ["Femenino", "Femenina"] else "El Dr."
        db.add(Notification(
            user_id=clinic.user_id,
            type=NotificationType.CLINIC_JOIN_APPROVED,
            title="Invitación aceptada",
            message=f"{prefix} {current_user.first_name} {current_user.last_name} ha aceptado tu invitación y se ha unido a tu clínica."
        ))
        msg = "Invitación aceptada"
    elif action == "reject":
        doc.requested_clinic_id = None
        doc.clinic_join_status = None
        msg = "Invitación rechazada"
    else:
        raise HTTPException(status_code=400, detail="Acción no válida")
        
    await db.commit()
    return {"message": msg}

