import base64
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import update
from app.core.database import get_db
from app.models.users import User
from app.api.v1.endpoints.users import get_current_user

router = APIRouter()

@router.post("/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    file_extension = file.filename.split(".")[-1]
    if file_extension.lower() not in ["jpg", "jpeg", "png", "gif", "webp"]:
        raise HTTPException(status_code=400, detail="El archivo no es una imagen válida")
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="La imagen está vacía")
    if len(image_bytes) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="La imagen supera el límite de 5 MB")

    content_type = file.content_type or {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "gif": "image/gif",
        "webp": "image/webp",
    }[file_extension.lower()]
    if not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="El archivo no es una imagen válida")

    current_user.avatar_data = base64.b64encode(image_bytes).decode("ascii")
    current_user.avatar_content_type = content_type
    avatar_url = f"/api/v1/users/{current_user.id}/avatar?v={uuid.uuid4().hex}"
    current_user.avatar_url = avatar_url
    db.add(current_user)
    await db.commit()
    
    return {"avatar_url": avatar_url}
