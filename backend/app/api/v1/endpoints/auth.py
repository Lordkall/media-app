from datetime import timedelta, datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import secrets
from app.core.database import get_db
from app.core.security import verify_password, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES
from app.models.users import User
from app.schemas.token import Token

router = APIRouter()

@router.post("/login", response_model=Token)
async def login_for_access_token(
    db: AsyncSession = Depends(get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
):
    from sqlalchemy import func
    query = select(User).where(func.lower(User.email) == form_data.username.lower())
    result = await db.execute(query)
    user = result.scalars().first()
    
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    from app.models.users import RoleEnum
    
    if user.role == RoleEnum.ASSISTANT:
        if not user.linked_doctor_id:
            raise HTTPException(status_code=403, detail="Asistente no vinculado a ningún doctor")
        
        from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
        import datetime
        now = datetime.datetime.utcnow()
        sub = await db.scalar(select(Subscription).where(
            Subscription.doctor_id == user.linked_doctor_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.plan == SubscriptionPlan.SPONSORED,
            Subscription.grace_end_date > now
        ))
        if not sub:
            raise HTTPException(status_code=403, detail="Acceso denegado. El doctor ya no cuenta con un plan VIP activo.")
            
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    session_id = secrets.token_urlsafe(32)
    user.session_token = session_id
    await db.commit()
    access_token = create_access_token(
        data={
            "sub": user.email,
            "id": str(user.id),
            "role": user.role.value,
            "sid": session_id,
        },
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

from app.schemas.users import UserCreate, UserResponse
from app.core.security import get_password_hash
from sqlalchemy.exc import IntegrityError
from app.models.users import RoleEnum as DatabaseRoleEnum

@router.post("/register", response_model=UserResponse)
async def register(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    try:
        requested_clinic = None
        if user_in.role.value == "doctor" and user_in.clinic_id is not None:
            from app.models.clinics import Clinic
            from app.core.clinic_access import active_clinic_subscription, clinic_has_capacity
            from app.models.doctors import Doctor

            requested_clinic = await db.scalar(
                select(Clinic).where(Clinic.id == user_in.clinic_id)
            )
            if not requested_clinic or not requested_clinic.is_approved:
                raise HTTPException(status_code=400, detail="La clínica seleccionada no está disponible")
            requested_clinic_user_state = await db.scalar(
                select(User.state).where(User.id == requested_clinic.user_id)
            )
            if requested_clinic_user_state != user_in.state:
                raise HTTPException(status_code=400, detail="La clínica debe pertenecer al mismo estado")
            clinic_sub = await active_clinic_subscription(db, requested_clinic.id)
            if not clinic_sub:
                raise HTTPException(status_code=400, detail="La clínica no tiene un plan activo")
            if not await clinic_has_capacity(db, requested_clinic.id, clinic_sub.plan):
                raise HTTPException(status_code=400, detail="La clínica alcanzó el máximo de doctores de su plan")

        new_user = User(
            email=user_in.email,
            first_name=user_in.first_name,
            last_name=user_in.last_name,
            phone=user_in.phone,
            hashed_password=get_password_hash(user_in.password),
            role=DatabaseRoleEnum(user_in.role.value),
            state=user_in.state,
            address=user_in.address,
            gender=user_in.gender,
            terms_accepted_at=datetime.now(timezone.utc),
            privacy_accepted_at=datetime.now(timezone.utc),
            terms_version="1.0",
            privacy_version="1.0",
        )
        db.add(new_user)
        await db.flush() # Para obtener new_user.id
        
        if user_in.role.value == "doctor":
            from app.models.doctors import Doctor
            new_doc = Doctor(
                user_id=new_user.id,
                specialties=user_in.specialties or [],
                bio="Nuevo especialista en la plataforma.",
                clinic_info=user_in.address,
                consultation_fee=50.0,
                is_sponsored=False,
                is_featured=False,
                is_approved=False,
                requested_clinic_id=requested_clinic.id if requested_clinic else None,
                clinic_join_status="pending" if requested_clinic else None,
            )
            db.add(new_doc)
            
            from app.models.notifications import Notification, NotificationType
            admin_query = await db.execute(select(User).where(User.role == "admin"))
            admins = admin_query.scalars().all()
            for admin in admins:
                notif = Notification(
                    user_id=admin.id,
                    type=NotificationType.DOCTOR_REGISTERED,
                    title="Nuevo Doctor Registrado",
                    message=f"El doctor {new_user.first_name} {new_user.last_name} se ha registrado. A la espera de que realice el pago de suscripción para su validación.",
                    action_url=None
                )
                db.add(notif)

            if requested_clinic:
                clinic_notification = Notification(
                    user_id=requested_clinic.user_id,
                    type=NotificationType.CLINIC_JOIN_REQUEST,
                    title="Solicitud de afiliación",
                    message=f"El doctor {new_user.first_name} {new_user.last_name} solicita unirse a tu clínica.",
                    action_url="clinic_doctor_requests",
                )
                db.add(clinic_notification)
                
        elif user_in.role.value == "patient":
            from app.models.patients import Patient
            new_pat = Patient(user_id=new_user.id, contact_phone=new_user.phone)
            db.add(new_pat)

        elif user_in.role.value == "clinic":
            from app.models.clinics import Clinic
            new_clinic = Clinic(
                user_id=new_user.id,
                description=user_in.clinic_description or "Nueva clínica en la plataforma.",
                is_approved=False,
                invite_code=secrets.token_urlsafe(9),
            )
            db.add(new_clinic)
            
            from app.models.notifications import Notification, NotificationType
            admin_query = await db.execute(select(User).where(User.role == "admin"))
            admins = admin_query.scalars().all()
            for admin in admins:
                notif = Notification(
                    user_id=admin.id,
                    type=NotificationType.DOCTOR_REGISTERED,  # Reusing this or creating CLINIC_REGISTERED
                    title="Nueva Clínica Registrada",
                    message=f"La clínica {new_user.first_name} se ha registrado. A la espera de que realice el pago de suscripción para su validación.",
                    action_url=None
                )
                db.add(notif)

        await db.commit()
        await db.refresh(new_user)
        return new_user
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo ya está registrado"
        )
