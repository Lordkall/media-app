import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.models.users import User
from app.models.password_reset import PasswordResetToken
from app.core.security import get_password_hash
from app.schemas.password_reset import PasswordResetRequest, PasswordResetConfirm
from app.services.email import send_reset_email

router = APIRouter()

@router.post("/request", status_code=status.HTTP_202_ACCEPTED)
async def request_password_reset(
    payload: PasswordResetRequest, 
    db: AsyncSession = Depends(get_db)
):
    query = select(User).where(User.email == payload.email)
    result = await db.execute(query)
    user = result.scalars().first()
    
    if user:
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        expires = datetime.now(timezone.utc) + timedelta(minutes=15)
        
        db_token = PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires
        )
        db.add(db_token)
        await db.commit()
        
        # En entorno local/desarrollo, frontend en localhost:3000
        FRONTEND_URL = "http://localhost:3000/reset-password"
        reset_link = f"{FRONTEND_URL}?token={raw_token}"
        
        try:
            import asyncio
            await asyncio.to_thread(send_reset_email, user.email, reset_link, raw_token)
        except Exception as e:
            raise HTTPException(status_code=400, detail=str(e))

    return {"message": "Si el correo está registrado, recibirás un enlace de recuperación pronto."}

@router.post("/confirm", status_code=status.HTTP_200_OK)
async def confirm_password_reset(
    payload: PasswordResetConfirm, 
    db: AsyncSession = Depends(get_db)
):
    token_hash = hashlib.sha256(payload.token.encode()).hexdigest()
    
    query = select(PasswordResetToken).where(
        PasswordResetToken.token_hash == token_hash,
        PasswordResetToken.is_used == False,
        PasswordResetToken.expires_at > datetime.now(timezone.utc)
    )
    result = await db.execute(query)
    reset_record = result.scalars().first()
    
    if not reset_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El token es inválido o ha expirado."
        )
        
    u_query = select(User).where(User.id == reset_record.user_id)
    u_result = await db.execute(u_query)
    user = u_result.scalars().first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
        
    user.hashed_password = get_password_hash(payload.new_password)
    reset_record.is_used = True
    
    await db.commit()
    
    return {"message": "Contraseña actualizada exitosamente."}
