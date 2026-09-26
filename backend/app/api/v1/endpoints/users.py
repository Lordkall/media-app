from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
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
    query = select(Notification).where(Notification.user_id == current_user.id).order_by(Notification.created_at.desc())
    if current_user.role.value != "admin":
        query = query.limit(3)
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
            "created_at": n.created_at.isoformat(),
            "payment_details": None
        }
        
        if n.action_url and n.action_url.startswith("approve_subscription:"):
            sub_id = int(n.action_url.split(":")[1])
            sub = await db.scalar(select(Subscription).where(Subscription.id == sub_id))
            from app.models.subscriptions import SubscriptionStatus
            if sub and sub.status == SubscriptionStatus.PENDING_APPROVAL:
                data["payment_details"] = {
                    "sub_id": sub.id,
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
