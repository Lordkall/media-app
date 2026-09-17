from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
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
