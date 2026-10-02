from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from typing import List, Any
from datetime import date, datetime, timezone
from app.core.database import get_db
from app.models.clinics import Clinic
from app.models.users import User
from app.models.doctors import Doctor, Availability
from pydantic import BaseModel
from app.api.v1.endpoints.users import get_current_user
from app.models.users import RoleEnum
from app.models.notifications import Notification, NotificationType

router = APIRouter()

class ClinicUpdate(BaseModel):
    description: str | None = None
    specialties: list[str] | None = None
    contact_phone_2: str | None = None

@router.get("/me")
async def get_my_clinic(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if current_user.role != RoleEnum.CLINIC:
        raise HTTPException(status_code=403, detail="Solo disponible para clínicas")
    clinic = await db.scalar(select(Clinic).where(Clinic.user_id == current_user.id))
    if not clinic:
        raise HTTPException(status_code=404, detail="Clínica no encontrada")
    return {
        "id": clinic.id,
        "name": current_user.first_name,
        "state": current_user.state,
        "description": clinic.description,
        "specialties": clinic.specialties or [],
        "contact_phone_2": clinic.contact_phone_2,
    }

@router.put("/me")
async def update_my_clinic(payload: ClinicUpdate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if current_user.role != RoleEnum.CLINIC:
        raise HTTPException(status_code=403, detail="Solo disponible para clínicas")
    clinic = await db.scalar(select(Clinic).where(Clinic.user_id == current_user.id))
    if not clinic:
        raise HTTPException(status_code=404, detail="Clínica no encontrada")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(clinic, key, value)
    await db.commit()
    return {"message": "Datos de clínica actualizados"}

from app.models.subscriptions import Subscription, SubscriptionPlan, SubscriptionStatus
from app.models.appointments import Appointment, AppointmentStatus
from app.models.notifications import Notification, NotificationType
from app.core.clinic_access import active_clinic_subscription, clinic_doctor_count, clinic_doctor_limit, clinic_has_capacity
import secrets

class ClinicResponse(BaseModel):
    id: int
    user_id: int
    description: str | None
    is_approved: bool
    first_name: str
    last_name: str
    email: str
    phone: str | None = None
    contact_phone_2: str | None = None
    address: str | None
    state: str | None = None
    avatar_url: str | None
    is_vip: bool

@router.get("/", response_model=List[ClinicResponse])
async def get_clinics(db: AsyncSession = Depends(get_db)):
    query = select(Clinic, User, Subscription).join(User, Clinic.user_id == User.id).outerjoin(
        Subscription, (Subscription.clinic_id == Clinic.id) & (Subscription.status == SubscriptionStatus.ACTIVE)
    ).where(Clinic.is_approved == True)
    result = await db.execute(query)
    rows = result.all()
    
    clinics = []
    for c, u, s in rows:
        is_vip = False
        if s and s.plan == SubscriptionPlan.CLINIC_VIP:
            is_vip = True
            
        clinics.append({
            "id": c.id,
            "user_id": c.user_id,
            "description": c.description,
            "is_approved": c.is_approved,
            "first_name": u.first_name,
            "last_name": u.last_name,
            "email": u.email,
            "phone": u.phone,
            "contact_phone_2": c.contact_phone_2,
            "address": u.address,
            "state": u.state,
            "avatar_url": u.avatar_url,
            "is_vip": is_vip
        })
    return clinics


@router.get("/available")
async def get_available_clinics(
    state: str = Query(min_length=1), db: AsyncSession = Depends(get_db)
):
    rows = await db.execute(
        select(Clinic, User, Subscription)
        .join(User, User.id == Clinic.user_id)
        .join(Subscription, Subscription.clinic_id == Clinic.id)
        .where(
            Clinic.is_approved.is_(True),
            User.state == state,
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.grace_end_date > datetime.now(timezone.utc),
            Subscription.plan.in_([SubscriptionPlan.CLINIC_BASIC, SubscriptionPlan.CLINIC_VIP]),
        )
        .order_by(User.first_name)
    )
    clinics = []
    for clinic, user, subscription in rows:
        capacity = clinic_doctor_limit(subscription.plan)
        count = await clinic_doctor_count(db, clinic.id)
        if count < capacity:
            clinics.append({
                "id": clinic.id,
                "name": user.first_name,
                "state": user.state,
                "doctor_count": count,
                "capacity": capacity,
                "plan": subscription.plan.value,
            })
    return clinics


@router.get("/invite/{invite_code}")
async def resolve_clinic_invite(invite_code: str, db: AsyncSession = Depends(get_db)):
    clinic = await db.scalar(
        select(Clinic).where(Clinic.invite_code == invite_code, Clinic.is_approved.is_(True))
    )
    if not clinic:
        raise HTTPException(status_code=404, detail="El enlace de invitación no es válido")
    subscription = await active_clinic_subscription(db, clinic.id)
    user = await db.get(User, clinic.user_id)
    if not subscription or not user or not await clinic_has_capacity(db, clinic.id, subscription.plan):
        raise HTTPException(status_code=409, detail="La clínica no acepta solicitudes en este momento")
    count = await clinic_doctor_count(db, clinic.id)
    return {
        "id": clinic.id,
        "name": user.first_name,
        "state": user.state,
        "doctor_count": count,
        "capacity": clinic_doctor_limit(subscription.plan),
    }

@router.post("/invite/{invite_code}/join")
async def join_clinic(invite_code: str, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if current_user.role != RoleEnum.DOCTOR:
        raise HTTPException(status_code=403, detail="Solo los doctores pueden unirse a una clínica")
        
    clinic = await db.scalar(
        select(Clinic).where(Clinic.invite_code == invite_code, Clinic.is_approved.is_(True))
    )
    if not clinic:
        raise HTTPException(status_code=404, detail="El enlace de invitación no es válido")
        
    subscription = await active_clinic_subscription(db, clinic.id)
    if not subscription or not await clinic_has_capacity(db, clinic.id, subscription.plan):
        raise HTTPException(status_code=409, detail="La clínica no acepta solicitudes en este momento")
        
    doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id).with_for_update())
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor no encontrado")
        
    doctor.requested_clinic_id = clinic.id
    doctor.clinic_join_status = "pending"
    
    prefix = "La Dra." if current_user.gender in ["Femenino", "Femenina"] else "El Dr."
    from app.models.notifications import Notification, NotificationType
    notif = Notification(
        user_id=clinic.user_id,
        type=NotificationType.CLINIC_JOIN_REQUEST,
        title="Nueva solicitud de afiliación",
        message=f"{prefix} {current_user.first_name} {current_user.last_name} ha solicitado unirse a tu clínica.",
    )
    db.add(notif)
    
    await db.commit()
    return {"message": "Solicitud enviada a la clínica"}


async def _owned_clinic(current_user: User, db: AsyncSession) -> Clinic:
    if current_user.role != RoleEnum.CLINIC:
        raise HTTPException(status_code=403, detail="Solo la clínica puede gestionar este módulo")
    clinic = await db.scalar(select(Clinic).where(Clinic.user_id == current_user.id))
    if not clinic:
        raise HTTPException(status_code=404, detail="Clínica no encontrada")
    return clinic


@router.get("/me/doctors")
async def get_my_doctors(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    clinic = await _owned_clinic(current_user, db)
    rows = await db.execute(
        select(Doctor, User).join(User, User.id == Doctor.user_id)
        .where(Doctor.clinic_id == clinic.id, or_(Doctor.clinic_join_status.is_(None), Doctor.clinic_join_status == "approved")).order_by(User.first_name)
    )
    from app.core.clinic_access import active_clinic_subscription, clinic_doctor_limit
    
    subscription = await active_clinic_subscription(db, clinic.id)
    max_doc = clinic_doctor_limit(subscription.plan) if subscription else 0

    doctors_list = [{
        "id": doctor.id, "user_id": user.id,
        "first_name": user.first_name, "last_name": user.last_name,
        "email": user.email, "phone": user.phone, "state": user.state,
        "address": doctor.clinic_info or user.address,
        "avatar_url": user.avatar_url,
        "specialties": doctor.specialties or [],
        "clinic_join_status": doctor.clinic_join_status or "approved",
        "bio": doctor.bio,
        "consultation_fee": doctor.consultation_fee,
        "is_vip": doctor.is_sponsored,
    } for doctor, user in rows]
    
    return {
        "doctors": doctors_list,
        "max_doctors": max_doc
    }


@router.get("/me/doctor-requests")
async def get_doctor_requests(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    clinic = await _owned_clinic(current_user, db)
    rows = await db.execute(
        select(Doctor, User).join(User, User.id == Doctor.user_id)
        .where(Doctor.requested_clinic_id == clinic.id, Doctor.clinic_join_status == "pending")
        .order_by(Doctor.id.desc())
    )
    return [{
        "doctor_id": doctor.id, "user_id": user.id,
        "first_name": user.first_name, "last_name": user.last_name,
        "email": user.email, "phone": user.phone,
        "specialties": doctor.specialties or [],
    } for doctor, user in rows]


@router.post("/me/doctors/{doctor_id}/approve")
async def approve_doctor_request(
    doctor_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    clinic = await _owned_clinic(current_user, db)
    doctor = await db.scalar(select(Doctor).where(Doctor.id == doctor_id).with_for_update())
    if not doctor or doctor.requested_clinic_id != clinic.id or doctor.clinic_join_status != "pending":
        raise HTTPException(status_code=404, detail="Solicitud pendiente no encontrada")
    subscription = await active_clinic_subscription(db, clinic.id)
    if not subscription:
        raise HTTPException(status_code=403, detail="La clínica necesita un plan activo para aceptar doctores")
    if not await clinic_has_capacity(db, clinic.id, subscription.plan):
        raise HTTPException(status_code=409, detail=f"El plan permite hasta {clinic_doctor_limit(subscription.plan)} doctores")
    doctor.clinic_id = clinic.id
    doctor.requested_clinic_id = None
    doctor.clinic_join_status = "approved"
    db.add(Notification(
        user_id=doctor.user_id,
        type=NotificationType.CLINIC_JOIN_APPROVED,
        title="Afiliación aprobada",
        message=f"La clínica {current_user.first_name} aprobó tu solicitud. Ya puedes acceder a Salud Now.",
        action_url="clinic_join_approved",
    ))
    await db.commit()
    return {"message": "Doctor aprobado", "clinic_id": clinic.id}


@router.post("/me/doctors/{doctor_id}/reject")
async def reject_doctor_request(
    doctor_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    clinic = await _owned_clinic(current_user, db)
    doctor = await db.scalar(select(Doctor).where(Doctor.id == doctor_id))
    if not doctor or doctor.requested_clinic_id != clinic.id or doctor.clinic_join_status != "pending":
        raise HTTPException(status_code=404, detail="Solicitud pendiente no encontrada")
    doctor.requested_clinic_id = None
    doctor.clinic_join_status = "rejected"
    await db.commit()
    return {"message": "Solicitud rechazada"}

@router.delete("/me/doctors/{doctor_id}")
async def remove_doctor(
    doctor_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    clinic = await _owned_clinic(current_user, db)
    doctor = await db.scalar(select(Doctor).where(Doctor.id == doctor_id).with_for_update())
    if not doctor or doctor.clinic_id != clinic.id:
        raise HTTPException(status_code=404, detail="Doctor no encontrado en tu clínica")
    
    doctor.clinic_id = None
    doctor.clinic_join_status = None
    await db.commit()
    return {"message": "Doctor expulsado correctamente"}


@router.get("/me/calendar")
async def get_clinic_calendar(
    year: int = Query(ge=2000, le=2100),
    month: int = Query(ge=1, le=12),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    clinic = await _owned_clinic(current_user, db)
    await _require_active_plan(db, clinic.id)
    start = date(year, month, 1)
    end = date(year + (month == 12), 1 if month == 12 else month + 1, 1)
    doctor_rows = await db.execute(
        select(Doctor, User).join(User, User.id == Doctor.user_id)
        .where(Doctor.clinic_id == clinic.id, or_(Doctor.clinic_join_status.is_(None), Doctor.clinic_join_status == "approved"))
    )
    doctors = doctor_rows.all()
    doctor_ids = [doctor.id for doctor, _ in doctors]
    if not doctor_ids:
        return {"year": year, "month": month, "days": []}
    availability_rows = await db.execute(
        select(Doctor.id, Availability.date)
        .join(Availability, Availability.doctor_id == Doctor.id)
        .where(Doctor.id.in_(doctor_ids), Availability.date >= start, Availability.date < end)
    )
    scheduled = {}
    for doctor_id, day in availability_rows:
        scheduled.setdefault(day.isoformat(), set()).add(doctor_id)
    appointment_rows = await db.execute(
        select(Appointment.appointment_date, Appointment.doctor_id, func.count(Appointment.id))
        .where(
            Appointment.doctor_id.in_(doctor_ids),
            Appointment.appointment_date >= start,
            Appointment.appointment_date < end,
            Appointment.status != AppointmentStatus.CANCELLED,
        )
        .group_by(Appointment.appointment_date, Appointment.doctor_id)
    )
    appointment_counts = {}
    for day, doctor_id, count in appointment_rows:
        appointment_counts.setdefault(day.isoformat(), {})[doctor_id] = count
        scheduled.setdefault(day.isoformat(), set()).add(doctor_id)
    doctor_map = {doctor.id: user for doctor, user in doctors}
    days = []
    for day in sorted(scheduled):
        counts = appointment_counts.get(day, {})
        days.append({
            "date": day,
            "appointment_count": sum(counts.values()),
            "doctors": [{
                "doctor_id": doctor_id,
                "name": f"{'Dra.' if doctor_map[doctor_id].gender in ['Femenino', 'Femenina'] else 'Dr.'} {doctor_map[doctor_id].first_name} {doctor_map[doctor_id].last_name}",
                "appointment_count": counts.get(doctor_id, 0),
                "profile_picture_url": doctor_map[doctor_id].avatar_url,
            } for doctor_id in sorted(scheduled[day])],
        })
    return {"year": year, "month": month, "days": days}


async def _require_active_plan(db: AsyncSession, clinic_id: int):
    subscription = await active_clinic_subscription(db, clinic_id)
    if not subscription:
        raise HTTPException(status_code=403, detail="La clínica no tiene un plan activo")
    return subscription


@router.get("/me/invite")
async def get_clinic_invite(
    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    clinic = await _owned_clinic(current_user, db)
    if not clinic.invite_code:
        clinic.invite_code = secrets.token_urlsafe(9)
        await db.commit()
    return {"code": clinic.invite_code, "url": f"https://saludnow.site/?clinic_invite={clinic.invite_code}"}
@router.get("/{clinic_id}/doctors")
async def get_clinic_doctors(clinic_id: int, db: AsyncSession = Depends(get_db)):
    query = select(Doctor, User).join(User, Doctor.user_id == User.id).where(Doctor.clinic_id == clinic_id)
    result = await db.execute(query)
    rows = result.all()
    
    docs = []
    for d, u in rows:
        docs.append({
            "id": d.id,
            "user_id": d.user_id,
            "first_name": u.first_name,
            "last_name": u.last_name,
            "specialties": d.specialties,
            "address": u.address,
            "consultation_fee": d.consultation_fee,
            "is_vip": d.is_sponsored,
            "avatar_url": u.avatar_url
        })
    return docs

