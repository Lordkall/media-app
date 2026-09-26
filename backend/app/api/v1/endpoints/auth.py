from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
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
    access_token = create_access_token(
        data={"sub": user.email, "id": str(user.id), "role": user.role.value},
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

from app.schemas.users import UserCreate, UserResponse
from app.core.security import get_password_hash
from sqlalchemy.exc import IntegrityError

@router.post("/register", response_model=UserResponse)
async def register(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    try:
        new_user = User(
            email=user_in.email,
            first_name=user_in.first_name,
            last_name=user_in.last_name,
            phone=user_in.phone,
            hashed_password=get_password_hash(user_in.password),
            role=user_in.role.value,
            state=user_in.state,
            address=user_in.address,
            gender=user_in.gender,
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
                is_approved=False
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
                
        elif user_in.role.value == "patient":
            from app.models.patients import Patient
            new_pat = Patient(user_id=new_user.id, contact_phone=new_user.phone)
            db.add(new_pat)

        elif user_in.role.value == "clinic":
            from app.models.clinics import Clinic
            new_clinic = Clinic(
                user_id=new_user.id,
                description=user_in.clinic_description or "Nueva clínica en la plataforma.",
                is_approved=False
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
