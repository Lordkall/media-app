import os
import shutil
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update
from app.core.database import get_db
from app.models.users import User
from app.api.v1.endpoints.users import get_current_user

router = APIRouter()

UPLOAD_DIR = "uploads/avatars"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    file_extension = file.filename.split(".")[-1]
    if file_extension.lower() not in ["jpg", "jpeg", "png", "gif", "webp"]:
        raise HTTPException(status_code=400, detail="El archivo no es una imagen válida")
    filename = f"user_{current_user.id}_{current_user.email.replace('@','_')}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    avatar_url = f"/api/v1/uploads/avatars/{filename}"
    
    current_user.avatar_url = avatar_url
    db.add(current_user)
    await db.commit()
    
    return {"avatar_url": avatar_url}
