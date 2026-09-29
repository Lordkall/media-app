from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Any
from app.core.database import get_db
from app.models.clinics import Clinic
from app.models.users import User
from app.models.doctors import Doctor
from pydantic import BaseModel
from app.api.v1.endpoints.users import get_current_user
from app.models.users import RoleEnum

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
    return {"description": clinic.description, "specialties": clinic.specialties or [], "contact_phone_2": clinic.contact_phone_2}

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

class ClinicResponse(BaseModel):
    id: int
    user_id: int
    description: str | None
    is_approved: bool
    first_name: str
    last_name: str
    email: str
    phone: str
    address: str | None
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
            "address": u.address,
            "avatar_url": u.avatar_url,
            "is_vip": is_vip
        })
    return clinics

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
