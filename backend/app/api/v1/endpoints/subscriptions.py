from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from datetime import datetime, timedelta
from typing import Optional
from pydantic import BaseModel

from app.core.database import get_db, engine
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
    normalized = " ".join(plan_name.strip().lower().replace("á", "a").split())
    plan_aliases = {
        "basic": SubscriptionPlan.BASIC,
        "basico": SubscriptionPlan.BASIC,
        "featured": SubscriptionPlan.FEATURED,
        "destacado": SubscriptionPlan.FEATURED,
        "sponsored": SubscriptionPlan.SPONSORED,
        "vip": SubscriptionPlan.SPONSORED,
        "patrocinado": SubscriptionPlan.SPONSORED,
        "plan vip patrocinado": SubscriptionPlan.SPONSORED,
        "clinic_basic": SubscriptionPlan.CLINIC_BASIC,
        "clinica basico": SubscriptionPlan.CLINIC_BASIC,
        "clinic_vip": SubscriptionPlan.CLINIC_VIP,
        "clinica vip": SubscriptionPlan.CLINIC_VIP,
    }
    try:
        return plan_aliases[normalized]
    except KeyError:
        raise HTTPException(status_code=422, detail="El plan seleccionado no es válido")


async def ensure_clinic_plan_enum_labels() -> None:
    """Repair legacy PostgreSQL enum labels before a clinic plan is inserted."""
    if engine.dialect.name != "postgresql":
        return
    async with engine.begin() as conn:
        await conn.execute(
            text("ALTER TYPE subscriptionplan ADD VALUE IF NOT EXISTS 'CLINIC_BASIC'")
        )
        await conn.execute(
            text("ALTER TYPE subscriptionplan ADD VALUE IF NOT EXISTS 'CLINIC_VIP'")
        )

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
    clinic_access_blocked: bool = False
    is_clinic_member: bool = False

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
        if doc.clinic_join_status == "pending":
            return DoctorSubscriptionsResponse(is_clinic_member=True)
        if doc.clinic_id:
            from app.core.clinic_access import active_clinic_subscription
            clinic_sub = await active_clinic_subscription(db, doc.clinic_id)
            if not clinic_sub:
                return DoctorSubscriptionsResponse(
                    clinic_access_blocked=True,
                    is_clinic_member=True,
                )
            return DoctorSubscriptionsResponse(
                current=SubscriptionDetail(
                    id=clinic_sub.id,
                    plan=clinic_sub.plan.value,
                    status=clinic_sub.status.value,
                    start_date=clinic_sub.start_date,
                    end_date=clinic_sub.end_date,
                    grace_end_date=clinic_sub.grace_end_date,
                ),
                is_clinic_member=True,
            )
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

@router.get("/test-renew-error")
async def test_renew_error(db: AsyncSession = Depends(get_db)):
    try:
        from app.models.users import User, RoleEnum
        admins_res = await db.execute(select(User))
        admins = [u for u in admins_res.scalars().all() if u.role == RoleEnum.ADMIN or u.role == "admin"]
        
        new_sub = Subscription(
            doctor_id=1,
            clinic_id=None,
            plan=SubscriptionPlan.BASIC,
            status=SubscriptionStatus.PENDING_APPROVAL,
            start_date=datetime.utcnow(),
            end_date=datetime.utcnow() + timedelta(days=30),
            grace_end_date=datetime.utcnow() + timedelta(days=35),
            reference_number="test1234",
            amount_bs=200.0,
            screenshot_base64="test"
        )
        db.add(new_sub)
        await db.flush()

        for admin in admins:
            notif = Notification(
                user_id=admin.id,
                type=NotificationType.NEW_SUBSCRIPTION,
                title="Test",
                message="Test",
                action_url=f"approve_subscription:{new_sub.id}" 
            )
            db.add(notif)
            
        await db.rollback()
        return {"status": "SUCCESS - NO ERROR THROWN"}
    except Exception as e:
        await db.rollback()
        import traceback
        return {"status": "ERROR", "error": str(e), "traceback": traceback.format_exc()}


@router.get("/fix-subscriptions-db")
async def fix_subscriptions_db(db: AsyncSession = Depends(get_db)):
    from sqlalchemy import text
    results = []
    
    # Fix doctors table first (this is the main blocking issue)
    doctors_columns = [
        "clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL",
        "max_patients_per_day INTEGER DEFAULT 5",
        "sponsored_priority INTEGER DEFAULT 99",
        "is_sponsored BOOLEAN DEFAULT FALSE",
        "is_featured BOOLEAN DEFAULT FALSE",
        "is_approved BOOLEAN DEFAULT FALSE",
        "rating FLOAT DEFAULT 0.0",
        "total_reviews INTEGER DEFAULT 0",
        "consultation_fee FLOAT",
        "bio TEXT",
        "clinic_info TEXT",
    ]
    for col_def in doctors_columns:
        col_name = col_def.split()[0]
        try:
            await db.execute(text(f"ALTER TABLE doctors ADD COLUMN IF NOT EXISTS {col_def}"))
            results.append(f"doctors.{col_name}: ok")
        except Exception as e:
            results.append(f"doctors.{col_name}: error ({str(e)[:80]})")
    
    # Fix subscriptions table
    sub_columns = [
        "clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL",
        "auto_renew BOOLEAN DEFAULT TRUE",
        "created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()",
        "updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()",
        "reference_number VARCHAR",
        "screenshot_base64 TEXT",
        "amount_bs FLOAT",
    ]
    for col_def in sub_columns:
        col_name = col_def.split()[0]
        try:
            await db.execute(text(f"ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS {col_def}"))
            results.append(f"subscriptions.{col_name}: ok")
        except Exception as e:
            results.append(f"subscriptions.{col_name}: error ({str(e)[:80]})")
    
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        results.append(f"COMMIT ERROR: {e}")
    
    return {"status": "ok", "results": results}

@router.get("/fix-all-db")
async def fix_all_db(db: AsyncSession = Depends(get_db)):
    """Fix all missing columns in doctors and subscriptions tables"""
    from sqlalchemy import text
    results = []
    
    # Fix doctors table
    doctors_columns = [
        "clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL",
        "max_patients_per_day INTEGER DEFAULT 5",
        "sponsored_priority INTEGER DEFAULT 99",
        "is_sponsored BOOLEAN DEFAULT FALSE",
        "is_featured BOOLEAN DEFAULT FALSE",
        "is_approved BOOLEAN DEFAULT FALSE",
        "rating FLOAT DEFAULT 0.0",
        "total_reviews INTEGER DEFAULT 0",
        "consultation_fee FLOAT",
        "bio TEXT",
        "clinic_info TEXT",
    ]
    for col_def in doctors_columns:
        col_name = col_def.split()[0]
        try:
            await db.execute(text(f"ALTER TABLE doctors ADD COLUMN IF NOT EXISTS {col_def}"))
            results.append(f"doctors.{col_name}: ok")
        except Exception as e:
            results.append(f"doctors.{col_name}: error ({str(e)[:80]})")
    
    # Fix subscriptions table
    sub_columns = [
        "clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL",
        "auto_renew BOOLEAN DEFAULT TRUE",
        "created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()",
        "updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()",
        "reference_number VARCHAR",
        "screenshot_base64 TEXT",
        "amount_bs FLOAT",
    ]
    for col_def in sub_columns:
        col_name = col_def.split()[0]
        try:
            await db.execute(text(f"ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS {col_def}"))
            results.append(f"subscriptions.{col_name}: ok")
        except Exception as e:
            results.append(f"subscriptions.{col_name}: error ({str(e)[:80]})")
    
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        results.append(f"COMMIT ERROR: {e}")
    
    return {"status": "done", "results": results}

@router.post("/renew", response_model=SubscriptionResponse)
async def renew_subscription(
    req: RenewRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    role = str(current_user.role.value) if hasattr(current_user.role, 'value') else str(current_user.role)
    if role not in ["doctor", "clinic"]:
        raise HTTPException(status_code=403, detail="Solo los doctores y clínicas pueden renovar suscripciones")

    if role == "clinic":
        try:
            await ensure_clinic_plan_enum_labels()
        except Exception as e:
            print(f"Could not ensure clinic subscription enum labels: {e}")
            raise HTTPException(
                status_code=503,
                detail="No se pudo preparar el plan de clínica. Inténtalo de nuevo más tarde.",
            ) from e

    if role == "doctor":
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
    if is_doctor and plan_enum in (SubscriptionPlan.CLINIC_BASIC, SubscriptionPlan.CLINIC_VIP):
        raise HTTPException(status_code=422, detail="Los planes de clínica solo pueden ser contratados por una clínica")
    if not is_doctor and plan_enum not in (SubscriptionPlan.CLINIC_BASIC, SubscriptionPlan.CLINIC_VIP):
        raise HTTPException(status_code=422, detail="Selecciona un plan para clínicas")
    
    if current_sub:
        start_date = current_sub.end_date
        if start_date.replace(tzinfo=None) < datetime.utcnow():
            start_date = datetime.utcnow()
            
        end_date = start_date + timedelta(days=days_added)
    else:
        start_date = datetime.utcnow()
        end_date = start_date + timedelta(days=days_added)

    try:
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
        admins_res = await db.execute(select(User))
        admins = [u for u in admins_res.scalars().all() if u.role == RoleEnum.ADMIN or u.role == "admin"]
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
    except Exception as e:
        print(f"Error in /renew ({type(e).__name__}): {e!r}")
        await db.rollback()
        raise HTTPException(
            status_code=500,
            detail="No se pudo registrar el pago. Inténtalo de nuevo más tarde.",
        ) from e

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
    role = str(current_user.role.value) if hasattr(current_user.role, 'value') else str(current_user.role)
    if role not in ["doctor", "clinic"]:
        raise HTTPException(status_code=403, detail="Solo los doctores y clínicas pueden cambiar de plan")

    if role == "doctor":
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

    try:
        # Notify admins
        admins_res = await db.execute(select(User))
        admins = [u for u in admins_res.scalars().all() if u.role == RoleEnum.ADMIN or u.role == "admin"]
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
    except Exception as e:
        print(f"Error in /change_plan: {e}")
        return SubscriptionResponse(
            status="ERROR",
            days_remaining=0,
            plan="ERROR",
            message=f"Error al procesar la notificación: {e}"
        )
    
    return SubscriptionResponse(
        status="PENDING_APPROVAL",
        days_remaining=total_days,
        plan=new_plan_enum.value,
        message=f"Pago por cambio de plan reportado. Dispondrás de un total de {total_days} días tras la validación."
    )
