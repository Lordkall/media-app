import json
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.users import get_current_user
from app.core.database import get_db
from app.models.ads import FloatingAd, FloatingAdMetric
from app.models.users import User

router = APIRouter()
TARGET_ROLES = {"patient", "doctor", "assistant", "clinic"}
SUPPORTED_IMAGES = {
    "jpg": ("image/jpeg", b"\xff\xd8\xff"),
    "jpeg": ("image/jpeg", b"\xff\xd8\xff"),
    "png": ("image/png", b"\x89PNG\r\n\x1a\n"),
    "webp": ("image/webp", b"RIFF"),
    "gif": ("image/gif", b"GIF8"),
}
MAX_IMAGE_BYTES = 8 * 1024 * 1024


def _role_value(user: User) -> str:
    return str(getattr(user.role, "value", user.role)).lower()


def _require_admin(user: User) -> None:
    if _role_value(user) != "admin":
        raise HTTPException(status_code=403, detail="Solo administración puede gestionar anuncios.")


def _ad_is_active(ad: FloatingAd, role: str) -> bool:
    expiration = ad.expires_at
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=timezone.utc)
    return ad.is_active and expiration > datetime.now(timezone.utc) and role in ad.target_roles


async def _ad_counts(db: AsyncSession, ad_id: int) -> dict[str, int]:
    result = await db.execute(
        select(FloatingAdMetric.event_type, func.count(FloatingAdMetric.id))
        .where(FloatingAdMetric.ad_id == ad_id)
        .group_by(FloatingAdMetric.event_type)
    )
    counts = {event: int(count) for event, count in result.all()}
    return {"views": counts.get("view", 0), "clicks": counts.get("click", 0)}


def _serialize(ad: FloatingAd, counts: dict[str, int] | None = None) -> dict:
    return {
        "id": ad.id,
        "title": ad.title,
        "image_url": ad.image_url,
        "link_url": ad.link_url,
        "target_roles": ad.target_roles,
        "expires_at": ad.expires_at.isoformat(),
        "is_active": ad.is_active,
        "created_at": ad.created_at.isoformat() if ad.created_at else None,
        "views": (counts or {}).get("views", 0),
        "clicks": (counts or {}).get("clicks", 0),
    }


@router.get("/active")
async def get_active_ads(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    role = _role_value(current_user)
    if role not in TARGET_ROLES:
        return []
    result = await db.execute(
        select(FloatingAd)
        .where(
            FloatingAd.is_active.is_(True),
            FloatingAd.expires_at > datetime.now(timezone.utc),
            FloatingAd.target_roles.contains([role]),
        )
        .order_by(FloatingAd.created_at.desc())
    )
    ads = result.scalars().all()
    return [_serialize(ad, await _ad_counts(db, ad.id)) for ad in ads if _ad_is_active(ad, role)]


@router.post("/{ad_id}/{event_type}")
async def record_ad_event(
    ad_id: int,
    event_type: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if event_type not in {"view", "click"}:
        raise HTTPException(status_code=404, detail="Evento de anuncio desconocido.")
    ad = await db.get(FloatingAd, ad_id)
    if ad is None or not _ad_is_active(ad, _role_value(current_user)):
        raise HTTPException(status_code=404, detail="El anuncio ya no está disponible.")

    existing = await db.scalar(
        select(FloatingAdMetric.id).where(
            FloatingAdMetric.ad_id == ad_id,
            FloatingAdMetric.user_id == current_user.id,
            FloatingAdMetric.event_type == event_type,
        )
    )
    recorded = existing is None
    if recorded:
        db.add(FloatingAdMetric(
            ad_id=ad_id,
            user_id=current_user.id,
            event_type=event_type,
        ))
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            recorded = False
    counts = await _ad_counts(db, ad_id)
    return {"recorded": recorded, **counts}


@router.get("/admin")
async def list_admin_ads(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_admin(current_user)
    result = await db.execute(select(FloatingAd).order_by(FloatingAd.created_at.desc()))
    ads = result.scalars().all()
    return [_serialize(ad, await _ad_counts(db, ad.id)) for ad in ads]


@router.post("/admin", status_code=201)
async def create_ad(
    title: str = Form(...),
    target_roles: str = Form(...),
    expires_at: datetime = Form(...),
    link_url: str | None = Form(default=None),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_admin(current_user)
    if not title.strip() or len(title.strip()) > 120:
        raise HTTPException(status_code=422, detail="El título debe tener entre 1 y 120 caracteres.")
    try:
        roles = json.loads(target_roles)
    except (TypeError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=422, detail="Selecciona al menos un tipo de usuario.") from exc
    if not isinstance(roles, list) or not roles or any(role not in TARGET_ROLES for role in roles):
        raise HTTPException(status_code=422, detail="La segmentación contiene un rol no válido.")
    roles = sorted(set(roles))
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= datetime.now(timezone.utc):
        raise HTTPException(status_code=422, detail="La fecha de expiración debe estar en el futuro.")

    normalized_link = link_url.strip() if link_url and link_url.strip() else None
    if normalized_link and not (normalized_link.startswith("http://") or normalized_link.startswith("https://")):
        raise HTTPException(status_code=422, detail="El enlace debe comenzar con http:// o https://")

    filename = (file.filename or "").lower()
    extension = filename.rsplit(".", 1)[-1] if "." in filename else ""
    if extension not in SUPPORTED_IMAGES:
        raise HTTPException(status_code=422, detail="Formato no admitido. Usa JPG, PNG, WebP o GIF.")

    payload = await file.read()
    if not payload:
        raise HTTPException(status_code=422, detail="La imagen no contiene datos.")
    if len(payload) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=422, detail="La imagen no debe superar los 8 MB.")

    _, magic_bytes = SUPPORTED_IMAGES[extension]
    if not payload.startswith(magic_bytes):
        raise HTTPException(status_code=422, detail="El contenido del archivo no coincide con su extensión.")

    upload_dir = Path("uploads/ads")
    upload_dir.mkdir(parents=True, exist_ok=True)
    stored_name = f"{uuid.uuid4().hex}.{extension}"
    destination = upload_dir / stored_name
    destination.write_bytes(payload)
    image_url = f"/api/v1/uploads/ads/{stored_name}"

    try:
        ad = FloatingAd(
            title=title.strip(),
            image_url=image_url,
            link_url=normalized_link,
            target_roles=roles,
            expires_at=expires_at,
            created_by=current_user.id,
        )
        db.add(ad)
        await db.commit()
        await db.refresh(ad)
        return _serialize(ad)
    except Exception:
        await db.rollback()
        try:
            destination.unlink(missing_ok=True)
        except OSError:
            pass
        raise


@router.patch("/admin/{ad_id}/toggle-active")
async def toggle_ad_active(
    ad_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_admin(current_user)
    ad = await db.get(FloatingAd, ad_id)
    if ad is None:
        raise HTTPException(status_code=404, detail="Anuncio no encontrado.")
    ad.is_active = not ad.is_active
    await db.commit()
    await db.refresh(ad)
    return _serialize(ad, await _ad_counts(db, ad.id))


@router.delete("/admin/{ad_id}")
async def delete_ad(
    ad_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    _require_admin(current_user)
    ad = await db.get(FloatingAd, ad_id)
    if ad is None:
        raise HTTPException(status_code=404, detail="Anuncio no encontrado.")

    # Remove stored image if exists
    if ad.image_url and "/uploads/" in ad.image_url:
        filename = ad.image_url.split("/uploads/")[-1]
        try:
            (Path("uploads") / filename).unlink(missing_ok=True)
        except OSError:
            pass

    await db.delete(ad)
    await db.commit()
    return {"message": "Anuncio eliminado correctamente."}
