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
    supported_types = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "gif": "image/gif",
        "webp": "image/webp",
    }
    filename = file.filename or ""
    file_extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    supplied_type = (file.content_type or "").split(";", 1)[0].strip().lower()
    if file_extension not in supported_types and supplied_type in supported_types.values():
        file_extension = next(
            extension for extension, mime_type in supported_types.items()
            if mime_type == supplied_type
        )
    if file_extension not in supported_types:
        raise HTTPException(status_code=400, detail="Formato no válido. Usa JPG, PNG, GIF o WEBP.")

    expected_type = supported_types[file_extension]
    if supplied_type in ("", "application/octet-stream", "binary/octet-stream"):
        # Some multipart clients omit the image MIME type. Infer it from the
        # validated file extension rather than rejecting an otherwise valid image.
        content_type = expected_type
    elif supplied_type == "image/jpg" and expected_type == "image/jpeg":
        content_type = "image/jpeg"
    elif supplied_type == expected_type:
        content_type = expected_type
    else:
        raise HTTPException(status_code=400, detail="El tipo de archivo no coincide con la imagen.")
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="La imagen está vacía")
    if len(image_bytes) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="La imagen supera el límite de 5 MB")

    current_user.avatar_data = base64.b64encode(image_bytes).decode("ascii")
    current_user.avatar_content_type = content_type
    avatar_url = f"/api/v1/users/{current_user.id}/avatar?v={uuid.uuid4().hex}"
    current_user.avatar_url = avatar_url
    db.add(current_user)
    await db.commit()
    
    return {"avatar_url": avatar_url}
