from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta
from typing import Optional
from pydantic import BaseModel

from app.core.database import get_db
from app.models.users import User, RoleEnum
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.models.notifications import Notification, NotificationType
from app.api.v1.endpoints.users import get_current_user

router = APIRouter()

class RenewRequest(BaseModel):
    billing_cycle: str  # "Mensual" or "Anual"
    reference_number: str
    plan_name: str
    amount_bs: Optional[float] = None
    screenshot_base64: Optional[str] = None

class ChangePlanRequest(BaseModel):
    new_plan_name: str
    billing_cycle: str  # "Mensual" or "Anual"
    reference_number: str
    amount_bs: Optional[float] = None
    screenshot_base64: Optional[str] = None

class SubscriptionResponse(BaseModel):
    status: str
    days_remaining: int
    plan: str
    message: str

def get_plan_enum(plan_name: str) -> SubscriptionPlan:
    plan_lower = plan_name.lower()
    if "clinic_vip" in plan_lower or "clínica vip" in plan_lower:
        return SubscriptionPlan.CLINIC_VIP
    elif "clinic_basic" in plan_lower or "clínica básico" in plan_lower:
        return SubscriptionPlan.CLINIC_BASIC
    elif "vip" in plan_lower or "patrocinado" in plan_lower:
        return SubscriptionPlan.SPONSORED
    elif "destacado" in plan_lower:
        return SubscriptionPlan.FEATURED
    else:
        return SubscriptionPlan.BASIC

def get_plan_price(plan: SubscriptionPlan, cycle: str) -> float:
    if plan == SubscriptionPlan.SPONSORED:
        return 40.0 * (12 if cycle == "Anual" else 1)
    elif plan == SubscriptionPlan.FEATURED:
        return 20.0 * (12 if cycle == "Anual" else 1)
    elif plan == SubscriptionPlan.CLINIC_VIP:
        return 250.0 * (12 if cycle == "Anual" else 1)
    elif plan == SubscriptionPlan.CLINIC_BASIC:
        return 150.0 * (12 if cycle == "Anual" else 1)
    return 0.0

class SubscriptionDetail(BaseModel):
    id: int
    plan: str
    status: str
    start_date: datetime
    end_date: datetime
    grace_end_date: datetime

class DoctorSubscriptionsResponse(BaseModel):
    current: Optional[SubscriptionDetail] = None
    pending: Optional[SubscriptionDetail] = None

@router.get("/me", response_model=DoctorSubscriptionsResponse)
async def get_my_subscriptions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role not in [RoleEnum.DOCTOR, RoleEnum.CLINIC]:
        raise HTTPException(status_code=403, detail="Solo los doctores y clínicas pueden ver suscripciones")

    if current_user.role == RoleEnum.DOCTOR:
        result = await db.execute(select(Doctor).where(Doctor.user_id == current_user.id))
        doc = result.scalars().first()
        if not doc:
            raise HTTPException(status_code=404, detail="Perfil de doctor no encontrado")
        entity_id = doc.id
        is_doctor = True
    else:
        from app.models.clinics import Clinic
        result = await db.execute(select(Clinic).where(Clinic.user_id == current_user.id))
        clinic = result.scalars().first()
        if not clinic:
            raise HTTPException(status_code=404, detail="Perfil de clínica no encontrado")
        entity_id = clinic.id
        is_doctor = False

    cond_active = Subscription.doctor_id == entity_id if is_doctor else Subscription.clinic_id == entity_id
    
    sub_res = await db.execute(
        select(Subscription).where(
            cond_active,
            Subscription.status == SubscriptionStatus.ACTIVE
        ).order_by(Subscription.created_at.desc())
    )
    current_sub = sub_res.scalars().first()
    
    pend_res = await db.execute(
        select(Subscription).where(
            cond_active,
            Subscription.status == SubscriptionStatus.PENDING_APPROVAL
        ).order_by(Subscription.created_at.desc())
    )
    pending_sub = pend_res.scalars().first()
    
    return DoctorSubscriptionsResponse(
        current=SubscriptionDetail(
            id=current_sub.id,
            plan=current_sub.plan.value,
            status=current_sub.status.value,
            start_date=current_sub.start_date,
            end_date=current_sub.end_date,
            grace_end_date=current_sub.grace_end_date
        ) if current_sub else None,
        pending=SubscriptionDetail(
            id=pending_sub.id,
            plan=pending_sub.plan.value,
            status=pending_sub.status.value,
            start_date=pending_sub.start_date,
            end_date=pending_sub.end_date,
            grace_end_date=pending_sub.grace_end_date
        ) if pending_sub else None
    )

@router.post("/renew", response_model=SubscriptionResponse)
async def renew_subscription(
    req: RenewRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role not in [RoleEnum.DOCTOR, RoleEnum.CLINIC]:
        raise HTTPException(status_code=403, detail="Solo los doctores y clínicas pueden renovar suscripciones")

    if current_user.role == RoleEnum.DOCTOR:
        result = await db.execute(select(Doctor).where(Doctor.user_id == current_user.id))
        doc = result.scalars().first()
        if not doc:
            raise HTTPException(status_code=404, detail="Perfil de doctor no encontrado")
        entity_id = doc.id
        is_doctor = True
    else:
        from app.models.clinics import Clinic
        result = await db.execute(select(Clinic).where(Clinic.user_id == current_user.id))
        clinic = result.scalars().first()
        if not clinic:
            raise HTTPException(status_code=404, detail="Perfil de clínica no encontrado")
        entity_id = clinic.id
        is_doctor = False

    cond_active = Subscription.doctor_id == entity_id if is_doctor else Subscription.clinic_id == entity_id

    # Find active plan
    sub_res = await db.execute(
        select(Subscription).where(
            cond_active,
            Subscription.status == SubscriptionStatus.ACTIVE
        ).order_by(Subscription.end_date.desc())
    )
    current_sub = sub_res.scalars().first()

    days_added = 365 if req.billing_cycle == "Anual" else 30
    plan_enum = get_plan_enum(req.plan_name)
    
    if current_sub:
        start_date = current_sub.end_date
        if start_date.replace(tzinfo=None) < datetime.utcnow():
            start_date = datetime.utcnow()
            
        end_date = start_date + timedelta(days=days_added)
    else:
        start_date = datetime.utcnow()
        end_date = start_date + timedelta(days=days_added)

    new_sub = Subscription(
        doctor_id=entity_id if is_doctor else None,
        clinic_id=entity_id if not is_doctor else None,
        plan=plan_enum,
        status=SubscriptionStatus.PENDING_APPROVAL,
        start_date=start_date,
        end_date=end_date,
        grace_end_date=end_date + timedelta(days=5),
        reference_number=req.reference_number,
        amount_bs=req.amount_bs,
        screenshot_base64=req.screenshot_base64
    )
    db.add(new_sub)
    await db.flush()

    # Notify admins
    admins_res = await db.execute(select(User).where(User.role == RoleEnum.ADMIN))
    admins = admins_res.scalars().all()
    for admin in admins:
        is_renewal = current_sub is not None
        title = "Renovación de Suscripción" if is_renewal else "Nueva Suscripción"
        msg = f"El Dr(a). {current_user.first_name} {current_user.last_name} reportó un pago para renovar {req.plan_name} ({req.billing_cycle}). Ref: {req.reference_number}" if is_renewal else f"El Dr(a). {current_user.first_name} {current_user.last_name} reportó el pago inicial de su suscripción {req.plan_name} ({req.billing_cycle}). Ref: {req.reference_number}"
        
        notif = Notification(
            user_id=admin.id,
            type=NotificationType.NEW_SUBSCRIPTION,
            title=title,
            message=msg,
            action_url=f"approve_subscription:{new_sub.id}" 
        )
        db.add(notif)
        
    await db.commit()

    return SubscriptionResponse(
        status="PENDING_APPROVAL",
        days_remaining=days_added,
        plan=plan_enum.value,
        message=f"Pago de renovación reportado exitosamente. Se añadirán {days_added} días tras la validación."
    )

@router.post("/change_plan", response_model=SubscriptionResponse)
async def change_subscription_plan(
    req: ChangePlanRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role not in [RoleEnum.DOCTOR, RoleEnum.CLINIC]:
        raise HTTPException(status_code=403, detail="Solo los doctores y clínicas pueden cambiar de plan")

    if current_user.role == RoleEnum.DOCTOR:
        result = await db.execute(select(Doctor).where(Doctor.user_id == current_user.id))
        doc = result.scalars().first()
        if not doc:
            raise HTTPException(status_code=404, detail="Perfil de doctor no encontrado")
        entity_id = doc.id
        is_doctor = True
    else:
        from app.models.clinics import Clinic
        result = await db.execute(select(Clinic).where(Clinic.user_id == current_user.id))
        clinic = result.scalars().first()
        if not clinic:
            raise HTTPException(status_code=404, detail="Perfil de clínica no encontrado")
        entity_id = clinic.id
        is_doctor = False

    cond_active = Subscription.doctor_id == entity_id if is_doctor else Subscription.clinic_id == entity_id

    sub_res = await db.execute(
        select(Subscription).where(
            cond_active,
            Subscription.status == SubscriptionStatus.ACTIVE
        ).order_by(Subscription.end_date.desc())
    )
    current_sub = sub_res.scalars().first()

    new_plan_enum = get_plan_enum(req.new_plan_name)
    days_purchased = 365 if req.billing_cycle == "Anual" else 30
    
    total_days = days_purchased
    
    if current_sub:
        # Calculate prorated equivalent days
        remaining_time = current_sub.end_date.replace(tzinfo=None) - datetime.utcnow()
        remaining_days = remaining_time.days if remaining_time.days > 0 else 0
        
        # Monthly prices for prorating
        old_monthly = get_plan_price(current_sub.plan, "Mensual")
        new_monthly = get_plan_price(new_plan_enum, "Mensual")
        
        if new_monthly > 0 and old_monthly > 0:
            equivalent_days = int(remaining_days * (old_monthly / new_monthly))
            total_days += equivalent_days

    start_date = datetime.utcnow()
    end_date = start_date + timedelta(days=total_days)

    new_sub = Subscription(
        doctor_id=entity_id if is_doctor else None,
        clinic_id=entity_id if not is_doctor else None,
        plan=new_plan_enum,
        status=SubscriptionStatus.PENDING_APPROVAL,
        start_date=start_date,
        end_date=end_date,
        grace_end_date=end_date + timedelta(days=5),
        reference_number=req.reference_number,
        amount_bs=req.amount_bs,
        screenshot_base64=req.screenshot_base64
    )
    db.add(new_sub)
    await db.flush()

    # Notify admins
    admins_res = await db.execute(select(User).where(User.role == RoleEnum.ADMIN))
    admins = admins_res.scalars().all()
    for admin in admins:
        notif = Notification(
            user_id=admin.id,
            type=NotificationType.NEW_SUBSCRIPTION,
            title="Cambio de Plan",
            message=f"El Dr(a). {current_user.first_name} {current_user.last_name} reportó un pago para cambiar a {req.new_plan_name} ({req.billing_cycle}). Ref: {req.reference_number}",
            action_url=f"approve_subscription:{new_sub.id}"
        )
        db.add(notif)
        
    await db.commit()
    
    return SubscriptionResponse(
        status="PENDING_APPROVAL",
        days_remaining=total_days,
        plan=new_plan_enum.value,
        message=f"Pago por cambio de plan reportado. Dispondrás de un total de {total_days} días tras la validación."
    )
