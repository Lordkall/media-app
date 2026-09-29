from fastapi import APIRouter, Depends, HTTPException, status, Response
from datetime import timezone
from zoneinfo import ZoneInfo
import base64
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import delete, select, update
from app.core.database import get_db
from app.models.users import User
from app.schemas.users import UserResponse, UserUpdate, PasswordChange

# ... (the rest is unchanged below, but the import was at line 6, I should replace line 6)
from app.api.v1.endpoints.auth import router as auth_router # just to import something if needed, but we'll use Depends
from jose import jwt, JWTError
from fastapi.security import OAuth2PasswordBearer
from app.core.security import SECRET_KEY, ALGORITHM, verify_password, get_password_hash

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("id")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    query = select(User).where(User.id == int(user_id))
    result = await db.execute(query)
    user = result.scalars().first()
    if user is None:
        raise credentials_exception
    return user

@router.get("/me", response_model=UserResponse)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.get("/{user_id}/avatar")
async def read_user_avatar(
    user_id: int,
    db: AsyncSession = Depends(get_db),
):
    user = await db.get(User, user_id)
    if not user or not user.avatar_data:
        raise HTTPException(status_code=404, detail="Avatar not found")
    return Response(
        content=base64.b64decode(user.avatar_data),
        media_type=user.avatar_content_type or "image/jpeg",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
        },
    )

@router.put("/me", response_model=UserResponse)
async def update_users_me(
    user_in: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    update_data = user_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)
        
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user

@router.put("/me/password")
async def update_password_me(
    pwd_in: PasswordChange,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if not verify_password(pwd_in.current_password, current_user.hashed_password):
        # Temp support for plaintext password like login
        if pwd_in.current_password != current_user.hashed_password:
            raise HTTPException(status_code=400, detail="Contraseña actual incorrecta")
            
    current_user.hashed_password = get_password_hash(pwd_in.new_password)
    db.add(current_user)
    await db.commit()
    return {"message": "Contraseña actualizada exitosamente"}

@router.delete("/me")
async def delete_my_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Anonymize the account while retaining appointment and billing references.
    import secrets
    current_user.email = f"deleted-{current_user.id}-{secrets.token_hex(8)}@invalid.saludnow"
    current_user.first_name = "Cuenta"
    current_user.last_name = "eliminada"
    current_user.phone = ""
    current_user.state = None
    current_user.address = None
    current_user.gender = None
    current_user.avatar_url = None
    current_user.avatar_data = None
    current_user.avatar_content_type = None
    current_user.session_token = None
    current_user.fcm_token = None
    current_user.hashed_password = get_password_hash(secrets.token_urlsafe(40))
    current_user.terms_accepted_at = None
    current_user.privacy_accepted_at = None
    current_user.terms_version = None
    current_user.privacy_version = None
    from app.models.patients import Patient
    from app.models.doctors import Doctor
    from app.models.clinics import Clinic
    patient = await db.scalar(select(Patient).where(Patient.user_id == current_user.id))
    if patient:
        patient.contact_phone = ""
    doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
    if doctor:
        doctor.bio = None
        doctor.clinic_info = None
        doctor.specialties = []
    clinic = await db.scalar(select(Clinic).where(Clinic.user_id == current_user.id))
    if clinic:
        clinic.description = None
        clinic.specialties = []
        clinic.contact_phone_2 = None
    await db.commit()
    return {"message": "Cuenta eliminada"}

@router.get("/bcv-rate")
async def get_bcv_rate(db: AsyncSession = Depends(get_db)):
    from app.models.exchange_rate import ExchangeRate
    result = await db.execute(select(ExchangeRate).where(ExchangeRate.moneda_origen == 'USD', ExchangeRate.moneda_destino == 'VES'))
    rate = result.scalar_one_or_none()
    return {"rate": rate.tasa if rate else 36.5}

@router.get("/me/notifications")
async def get_my_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    from app.models.notifications import Notification
    from app.models.subscriptions import Subscription
    role_str = str(current_user.role.value) if hasattr(current_user.role, 'value') else str(current_user.role)
    query = select(Notification).where(Notification.user_id == current_user.id).order_by(Notification.created_at.desc())
    result = await db.execute(query)
    notifications = result.scalars().all()
    
    out = []
    for n in notifications:
        data = {
            "id": n.id,
            "type": n.type.value,
            "title": n.title,
            "message": n.message,
            "is_read": n.is_read,
            "action_url": n.action_url,
            "created_at": (
                n.created_at.replace(tzinfo=timezone.utc)
                if n.created_at.tzinfo is None
                else n.created_at
            ).astimezone(ZoneInfo("America/Caracas")).isoformat(),
            "payment_details": None
        }
        
        if n.action_url and n.action_url.startswith("approve_subscription:"):
            sub_id = int(n.action_url.split(":")[1])
            sub = await db.scalar(select(Subscription).where(Subscription.id == sub_id))
            from app.models.subscriptions import SubscriptionStatus
            if sub:
                owner_name = "Usuario"
                entity_kind = "doctor"
                if sub.doctor_id:
                    from app.models.doctors import Doctor
                    doctor_user_id = await db.scalar(
                        select(Doctor.user_id).where(Doctor.id == sub.doctor_id)
                    )
                    owner = await db.get(User, doctor_user_id) if doctor_user_id else None
                    if owner:
                        owner_name = f"Dr. {owner.first_name} {owner.last_name}"
                elif sub.clinic_id:
                    from app.models.clinics import Clinic
                    clinic_user_id = await db.scalar(
                        select(Clinic.user_id).where(Clinic.id == sub.clinic_id)
                    )
                    owner = await db.get(User, clinic_user_id) if clinic_user_id else None
                    entity_kind = "clinic"
                    if owner:
                        owner_name = f"{owner.first_name} {owner.last_name}"
                if n.title == "Pago Aprobado":
                    payment_decision = "approved"
                elif n.title == "Pago Rechazado":
                    payment_decision = "rejected"
                elif sub.status == SubscriptionStatus.PENDING_APPROVAL:
                    payment_decision = "pending"
                else:
                    # Preserve the payment decision even if a later plan replaces
                    # this subscription and changes its current status to cancelled.
                    payment_decision = "approved" if sub.status in (
                        SubscriptionStatus.ACTIVE,
                        SubscriptionStatus.EXPIRED,
                        SubscriptionStatus.GRACE_PERIOD,
                    ) else "rejected"

                data["payment_details"] = {
                    "sub_id": sub.id,
                    "owner_name": owner_name,
                    "entity_kind": entity_kind,
                    "plan": sub.plan.value,
                    "status": payment_decision,
                    "reference_number": sub.reference_number,
                    "amount_bs": sub.amount_bs,
                    "screenshot_base64": sub.screenshot_base64
                }
        out.append(data)
        
    return out

@router.post("/me/notifications/read")
async def mark_notifications_as_read(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    from app.models.notifications import Notification
    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id)
        .where(Notification.is_read == False)
        .values(is_read=True)
    )
    await db.commit()
    return {"status": "ok"}


@router.delete("/me/notifications")
async def delete_my_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.models.notifications import Notification

    result = await db.execute(
        delete(Notification).where(Notification.user_id == current_user.id)
    )
    await db.commit()
    return {"status": "ok", "deleted": result.rowcount or 0}
