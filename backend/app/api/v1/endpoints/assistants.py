from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Dict, Any
from app.core.database import get_db
from app.core.security import get_password_hash
from app.models.users import User, RoleEnum
from app.models.doctors import Doctor
from app.api.v1.endpoints.users import get_current_user
from pydantic import BaseModel, EmailStr, field_validator
import re

_VENEZUELAN_STATES = {
    "Amazonas", "Anzoátegui", "Apure", "Aragua", "Barinas", "Bolívar",
    "Carabobo", "Cojedes", "Delta Amacuro", "Dependencias Federales",
    "Distrito Capital", "Falcón", "Guárico", "La Guaira", "Lara",
    "Mérida", "Miranda", "Monagas", "Nueva Esparta", "Portuguesa",
    "Sucre", "Táchira", "Trujillo", "Yaracuy", "Zulia",
}

router = APIRouter()

class AssistantCreate(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    phone: str
    state: str

    @field_validator("phone")
    @classmethod
    def valid_phone(cls, value: str) -> str:
        cleaned = value.strip()
        if not re.fullmatch(r"\d{1,11}", cleaned):
            raise ValueError("El teléfono debe tener solo números y máximo 11 dígitos")
        return cleaned

    @field_validator("password")
    @classmethod
    def valid_password(cls, value: str) -> str:
        if len(value) < 6 or not re.search(r"[A-Z]", value) or not re.search(r"[a-zA-Z]", value) or not re.search(r"\d", value):
            raise ValueError("La contraseña debe tener al menos 6 caracteres, una mayúscula, letras y números")
        return value

    @field_validator("state")
    @classmethod
    def valid_state(cls, value: str) -> str:
        if value not in _VENEZUELAN_STATES:
            raise ValueError("Selecciona un estado válido")
        return value

@router.get("/", response_model=List[Dict[str, Any]])
async def get_assistants(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != RoleEnum.DOCTOR:
        raise HTTPException(status_code=403, detail="Solo doctores pueden ver sus asistentes")
    
    doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
    if not doctor:
        raise HTTPException(status_code=404, detail="Perfil de doctor no encontrado")
        
    result = await db.execute(select(User).where(User.linked_doctor_id == doctor.id, User.role == RoleEnum.ASSISTANT))
    assistants = result.scalars().all()
    
    return [
        {
            "id": a.id,
            "first_name": a.first_name,
            "last_name": a.last_name,
            "email": a.email,
        }
        for a in assistants
    ]

@router.post("/")
async def create_assistant(
    assistant_in: AssistantCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != RoleEnum.DOCTOR:
        raise HTTPException(status_code=403, detail="Solo doctores pueden crear asistentes")
        
    doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id).with_for_update())
    if not doctor:
        raise HTTPException(status_code=404, detail="Perfil de doctor no encontrado")

    assistant_count = await db.scalar(
        select(User.id).where(
            User.role == RoleEnum.ASSISTANT,
            User.linked_doctor_id == doctor.id,
        ).limit(1)
    )
    if assistant_count is not None:
        raise HTTPException(status_code=400, detail="Cada doctor puede tener un solo asistente")
        
    existing_user = await db.scalar(select(User).where(User.email == assistant_in.email))
    if existing_user:
        raise HTTPException(status_code=400, detail="El correo ya está registrado")
        
    new_assistant = User(
        email=assistant_in.email,
        first_name=assistant_in.first_name,
        last_name=assistant_in.last_name,
        phone=assistant_in.phone,
        hashed_password=get_password_hash(assistant_in.password),
        role=RoleEnum.ASSISTANT,
        linked_doctor_id=doctor.id,
        state=assistant_in.state,
    )
    
    db.add(new_assistant)
    await db.commit()
    return {"message": "Asistente creado exitosamente"}

@router.delete("/{assistant_id}")
async def delete_assistant(
    assistant_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if current_user.role != RoleEnum.DOCTOR:
        raise HTTPException(status_code=403, detail="Solo doctores pueden eliminar asistentes")
        
    doctor = await db.scalar(select(Doctor).where(Doctor.user_id == current_user.id))
    
    assistant = await db.scalar(select(User).where(User.id == assistant_id, User.role == RoleEnum.ASSISTANT, User.linked_doctor_id == doctor.id))
    if not assistant:
        raise HTTPException(status_code=404, detail="Asistente no encontrado o no pertenece a este doctor")
        
    await db.delete(assistant)
    await db.commit()
    return {"message": "Asistente eliminado"}
