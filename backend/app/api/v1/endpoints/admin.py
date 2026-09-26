from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.core.database import get_db
from app.models.users import User, RoleEnum
from app.models.doctors import Doctor
from app.models.patients import Patient
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.models.notifications import Notification, NotificationType
from app.api.v1.endpoints.users import get_current_user
from typing import List, Dict, Any

router = APIRouter()

def check_admin(user: User):
    if user.role != RoleEnum.ADMIN:
        raise HTTPException(status_code=403, detail="Not authorized. Admin role required.")

@router.get("/stats")
async def get_admin_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    # Counts
    patients_count = await db.scalar(select(func.count()).select_from(Patient))
    doctors_count = await db.scalar(select(func.count()).select_from(Doctor))
    subs_count = await db.scalar(
        select(func.count())
        .select_from(Subscription)
        .where(Subscription.status == SubscriptionStatus.ACTIVE)
    )
    
    # State distribution (from User)
    state_patients = await db.execute(
        select(User.state, func.count(Patient.id))
        .join(Patient, User.id == Patient.user_id)
        .group_by(User.state)
    )
    
    state_doctors = await db.execute(
        select(User.state, func.count(Doctor.id))
        .join(Doctor, User.id == Doctor.user_id)
        .group_by(User.state)
    )
    
    states_dict = {}
    for state, count in state_patients:
        if state:
            states_dict[state] = {"name": state, "patients": count, "doctors": 0}
            
    for state, count in state_doctors:
        if state:
            if state not in states_dict:
                states_dict[state] = {"name": state, "patients": 0, "doctors": 0}
            states_dict[state]["doctors"] = count
            
    return {
        "patients_count": patients_count or 0,
        "doctors_count": doctors_count or 0,
        "subscribed_doctors": subs_count or 0,
        "states": list(states_dict.values())
    }

@router.get("/doctors")
async def get_all_doctors(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Public route or admin route? Browsing doctors is public (patients can see them)
    # So we don't strictly require admin here, but since it's in admin router maybe we just return all
    # For now we'll allow any logged in user
    query = select(Doctor, User, Subscription).join(User, Doctor.user_id == User.id).outerjoin(
        Subscription, 
        (Subscription.doctor_id == Doctor.id) & (Subscription.status == SubscriptionStatus.ACTIVE)
    )
    result = await db.execute(query)
    
    doctors_list = []
    for doc, user, sub in result:
        days_remaining = 0
        if sub and sub.end_date:
            import datetime
            now = datetime.datetime.utcnow()
            end = sub.end_date.replace(tzinfo=None)
            days_remaining = (end - now).days if end > now else 0

        doctors_list.append({
            "id": doc.id,
            "user_id": user.id,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "specialties": doc.specialties or [],
            "state": user.state,
            "address": user.address or 'Sin dirección registrada',
            "consultation_fee": doc.consultation_fee or 0.0,
            "avatar_url": user.avatar_url,
            "is_vip": sub is not None and sub.plan == SubscriptionPlan.SPONSORED,
            "plan": sub.plan.value if sub else "Ninguno",
            "subscription_id": sub.id if sub else None,
            "days_remaining": days_remaining,
            "clinic_id": doc.clinic_id
        })
        
    return doctors_list

@router.post("/subscriptions/{doctor_id}/activate")
async def activate_subscription(
    doctor_id: int,
    plan: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    doc = await db.scalar(select(Doctor).where(Doctor.id == doctor_id))
    if not doc:
        raise HTTPException(status_code=404, detail="Doctor not found")
        
    import datetime
    now = datetime.datetime.utcnow()
    
    # Deactivate existing
    existing = await db.execute(select(Subscription).where(Subscription.doctor_id == doctor_id, Subscription.status == SubscriptionStatus.ACTIVE))
    existing_subs = existing.scalars().all()
    
    new_days = 30
    
    if existing_subs:
        old_sub = existing_subs[0]
        for e in existing_subs:
            e.status = SubscriptionStatus.CANCELLED
            
        if old_sub.end_date and old_sub.end_date.replace(tzinfo=None) > now:
            remaining_days = (old_sub.end_date.replace(tzinfo=None) - now).days
            
            if old_sub.plan in [SubscriptionPlan.BASIC, SubscriptionPlan.FEATURED] and plan == 'sponsored':
                new_days = remaining_days // 2
            elif old_sub.plan == SubscriptionPlan.SPONSORED and plan in ['basic', 'featured']:
                new_days = remaining_days * 2
            else:
                new_days = remaining_days
                
            if new_days < 0:
                new_days = 0

    end_date = now + datetime.timedelta(days=new_days)
    new_sub = Subscription(
        doctor_id=doctor_id,
        plan=SubscriptionPlan(plan),
        status=SubscriptionStatus.ACTIVE,
        start_date=now,
        end_date=end_date,
        grace_end_date=end_date + datetime.timedelta(days=5)
    )
    db.add(new_sub)
    await db.commit()
    return {"message": "Subscription activated"}

@router.post("/subscriptions/{doctor_id}/renew")
async def renew_subscription(
    doctor_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    sub = await db.scalar(select(Subscription).where(Subscription.doctor_id == doctor_id, Subscription.status == SubscriptionStatus.ACTIVE))
    if not sub:
        raise HTTPException(status_code=400, detail="No active subscription to renew")
        
    import datetime
    sub.end_date = sub.end_date + datetime.timedelta(days=30)
    await db.commit()
    return {"message": "Subscription renewed"}

@router.post("/subscriptions/{doctor_id}/deactivate")
async def deactivate_subscription(
    doctor_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    sub = await db.scalar(select(Subscription).where(Subscription.doctor_id == doctor_id, Subscription.status == SubscriptionStatus.ACTIVE))
    if sub:
        sub.status = SubscriptionStatus.CANCELLED
        await db.commit()
    return {"message": "Subscription deactivated"}

@router.post("/subscriptions/{sub_id}/approve")
async def approve_subscription(
    sub_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    sub = await db.scalar(select(Subscription).where(Subscription.id == sub_id))
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
        
    import datetime
    
    # Cancel previous active subscriptions for this doctor
    existing = await db.execute(select(Subscription).where(
        Subscription.doctor_id == sub.doctor_id, 
        Subscription.status == SubscriptionStatus.ACTIVE,
        Subscription.id != sub.id
    ))
    for e in existing.scalars():
        e.status = SubscriptionStatus.CANCELLED
        
    sub.status = SubscriptionStatus.ACTIVE
    # Update start date to now, so it's immediately active (end_date is already extended)
    sub.start_date = datetime.datetime.utcnow()
    
    # Update notification
    notifs = await db.execute(select(Notification).where(Notification.action_url == f"approve_subscription:{sub.id}"))
    for n in notifs.scalars():
        n.is_read = True
        n.title = "Pago Aprobado"
        n.message = "La suscripción fue activada exitosamente."
        
    await db.commit()
    return {"message": "Subscription approved"}

@router.post("/subscriptions/{sub_id}/reject")
async def reject_subscription(
    sub_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    sub = await db.scalar(select(Subscription).where(Subscription.id == sub_id))
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
        
    sub.status = SubscriptionStatus.CANCELLED
    
    notifs = await db.execute(select(Notification).where(Notification.action_url == f"approve_subscription:{sub.id}"))
    for n in notifs.scalars():
        n.is_read = True
        n.title = "Pago Rechazado"
        n.message = "La solicitud de suscripción fue rechazada."
        
    await db.commit()
    return {"message": "Subscription rejected"}
