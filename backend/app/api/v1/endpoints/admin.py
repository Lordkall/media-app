from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.core.database import get_db
from app.models.users import User, RoleEnum
from app.models.doctors import Doctor
from app.models.patients import Patient
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.models.notifications import Notification, NotificationType
from app.models.clinics import Clinic
from app.api.v1.endpoints.users import get_current_user
from typing import List, Dict, Any

router = APIRouter()

def check_admin(user: User):
    if user.role != RoleEnum.ADMIN:
        raise HTTPException(status_code=403, detail="Not authorized. Admin role required.")


async def sync_doctor_plan_flags(db: AsyncSession, doctor_id: int, plan: SubscriptionPlan):
    doctor = await db.scalar(select(Doctor).where(Doctor.id == doctor_id))
    if doctor:
        doctor.is_sponsored = plan == SubscriptionPlan.SPONSORED
        doctor.is_featured = plan == SubscriptionPlan.FEATURED
        doctor.sponsored_priority = 1 if doctor.is_sponsored else 99

@router.get("/stats")
async def get_admin_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    patients_count = await db.scalar(select(func.count()).select_from(Patient))
    doctors_count = await db.scalar(select(func.count()).select_from(Doctor))
    clinics_count = await db.scalar(select(func.count()).select_from(Clinic))
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
    
    state_clinics = await db.execute(
        select(User.state, func.count(Clinic.id))
        .join(Clinic, User.id == Clinic.user_id)
        .group_by(User.state)
    )
    
    states_dict = {}
    for state, count in state_patients:
        if state:
            states_dict[state] = {"name": state, "patients": count, "doctors": 0, "clinics": 0}
            
    for state, count in state_doctors:
        if state:
            if state not in states_dict:
                states_dict[state] = {"name": state, "patients": 0, "doctors": 0, "clinics": 0}
            states_dict[state]["doctors"] = count
            
    for state, count in state_clinics:
        if state:
            if state not in states_dict:
                states_dict[state] = {"name": state, "patients": 0, "doctors": 0, "clinics": 0}
            states_dict[state]["clinics"] = count
            
    return {
        "patients_count": patients_count or 0,
        "doctors_count": doctors_count or 0,
        "clinics_count": clinics_count or 0,
        "subscribed_doctors": subs_count or 0,
        "states": list(states_dict.values())
    }

@router.get("/doctors")
async def get_all_doctors(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
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

        # Also check for pending approval subscriptions
        pending_sub = await db.scalar(select(Subscription).where(
            Subscription.doctor_id == doc.id,
            Subscription.status == SubscriptionStatus.PENDING_APPROVAL
        ))

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
            "clinic_id": doc.clinic_id,
            # Pending payment info
            "pending_sub_id": pending_sub.id if pending_sub else None,
            "pending_plan": pending_sub.plan.value if pending_sub else None,
            "pending_reference": pending_sub.reference_number if pending_sub else None,
            "pending_amount_bs": pending_sub.amount_bs if pending_sub else None,
        })
        
    return doctors_list


@router.get("/clinics")
async def get_all_clinics(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(Clinic, User, Subscription).join(User, Clinic.user_id == User.id).outerjoin(
        Subscription, 
        (Subscription.clinic_id == Clinic.id) & (Subscription.status == SubscriptionStatus.ACTIVE)
    )
    result = await db.execute(query)
    
    clinics_list = []
    for clinic, user, sub in result:
        days_remaining = 0
        if sub and sub.end_date:
            import datetime
            now = datetime.datetime.utcnow()
            end = sub.end_date.replace(tzinfo=None)
            days_remaining = (end - now).days if end > now else 0

        clinics_list.append({
            "id": clinic.id,
            "user_id": user.id,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "specialties": ["Clínica"],
            "state": user.state,
            "address": user.address or 'Sin dirección registrada',
            "consultation_fee": 0.0,
            "avatar_url": user.avatar_url,
            "is_vip": sub is not None and sub.plan == SubscriptionPlan.CLINIC_VIP,
            "plan": sub.plan.value if sub else "Ninguno",
            "subscription_id": sub.id if sub else None,
            "days_remaining": days_remaining,
        })
        
    return clinics_list

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
    await sync_doctor_plan_flags(db, doctor_id, new_sub.plan)
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

@router.post("/clinic_subscriptions/{clinic_id}/activate")
async def activate_clinic_subscription(
    clinic_id: int,
    plan: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    cli = await db.scalar(select(Clinic).where(Clinic.id == clinic_id))
    if not cli:
        raise HTTPException(status_code=404, detail="Clinic not found")
        
    import datetime
    now = datetime.datetime.utcnow()
    
    existing = await db.execute(select(Subscription).where(Subscription.clinic_id == clinic_id, Subscription.status == SubscriptionStatus.ACTIVE))
    existing_subs = existing.scalars().all()
    
    new_days = 30
    
    if existing_subs:
        old_sub = existing_subs[0]
        for e in existing_subs:
            e.status = SubscriptionStatus.CANCELLED
            
        if old_sub.end_date and old_sub.end_date.replace(tzinfo=None) > now:
            new_days = (old_sub.end_date.replace(tzinfo=None) - now).days

    end_date = now + datetime.timedelta(days=new_days)
    new_sub = Subscription(
        clinic_id=clinic_id,
        plan=SubscriptionPlan(plan),
        status=SubscriptionStatus.ACTIVE,
        start_date=now,
        end_date=end_date,
        grace_end_date=end_date + datetime.timedelta(days=5)
    )
    db.add(new_sub)
    await db.commit()
    return {"message": "Subscription activated"}

@router.post("/clinic_subscriptions/{clinic_id}/renew")
async def renew_clinic_subscription(
    clinic_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    sub = await db.scalar(select(Subscription).where(Subscription.clinic_id == clinic_id, Subscription.status == SubscriptionStatus.ACTIVE))
    if not sub:
        raise HTTPException(status_code=400, detail="No active subscription to renew")
        
    import datetime
    sub.end_date = sub.end_date + datetime.timedelta(days=30)
    await db.commit()
    return {"message": "Subscription renewed"}

@router.post("/clinic_subscriptions/{clinic_id}/deactivate")
async def deactivate_clinic_subscription(
    clinic_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    check_admin(current_user)
    
    sub = await db.scalar(select(Subscription).where(Subscription.clinic_id == clinic_id, Subscription.status == SubscriptionStatus.ACTIVE))
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
    
    # Cancel previous active subscriptions for this doctor (not the one being approved)
    if sub.doctor_id:
        existing = await db.execute(select(Subscription).where(
            Subscription.doctor_id == sub.doctor_id, 
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.id != sub.id
        ))
        for e in existing.scalars():
            e.status = SubscriptionStatus.CANCELLED
    
    if sub.clinic_id:
        existing = await db.execute(select(Subscription).where(
            Subscription.clinic_id == sub.clinic_id, 
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.id != sub.id
        ))
        for e in existing.scalars():
            e.status = SubscriptionStatus.CANCELLED
        
    sub.status = SubscriptionStatus.ACTIVE
    sub.start_date = datetime.datetime.utcnow()
    if sub.doctor_id:
        await sync_doctor_plan_flags(db, sub.doctor_id, sub.plan)
    # Set grace end date (5 days after end_date)
    if sub.end_date:
        sub.grace_end_date = sub.end_date + datetime.timedelta(days=5)
    
    # Update notification to approved
    notifs = await db.execute(select(Notification).where(Notification.action_url == f"approve_subscription:{sub.id}"))
    for n in notifs.scalars():
        n.is_read = True
        n.title = "Pago Aprobado"
        n.message = f"La suscripción plan {sub.plan.value} fue activada exitosamente."
        
    # Notify the doctor/clinic their plan was approved
    try:
        target_user_id = None
        if sub.doctor_id:
            doc = await db.scalar(select(Doctor).where(Doctor.id == sub.doctor_id))
            if doc:
                target_user_id = doc.user_id
        
        if target_user_id:
            approval_notif = Notification(
                user_id=target_user_id,
                type=NotificationType.DOCTOR_APPROVED,
                title="¡Suscripción Aprobada!",
                message=f"Tu plan {sub.plan.value} ha sido activado. ¡Bienvenido a Salud Now!",
                action_url=None
            )
            db.add(approval_notif)
            
            # Send Firebase push notification
            from app.core.firebase import send_push_notification
            target_user = await db.scalar(select(User).where(User.id == target_user_id))
            if target_user and target_user.fcm_token:
                send_push_notification(
                    target_user.fcm_token,
                    "¡Suscripción Aprobada!",
                    f"Tu plan {sub.plan.value} ha sido activado. ¡Bienvenido a Salud Now!"
                )
    except Exception as e:
        print(f"Error sending approval notification: {e}")
        
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
