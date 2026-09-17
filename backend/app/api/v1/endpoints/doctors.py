from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.users import User
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.schemas.doctors import DoctorResponse, DoctorUpdate
from app.api.v1.endpoints.users import get_current_user

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
        
    db.add(doc)
    await db.commit()
    await db.refresh(doc)
    
    doc.is_vip = False # Temporarily assume false on update, since the UI usually only reads this on get
    return doc
