from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
from enum import Enum
from datetime import date
from app.core.demographics import local_today
from pydantic import model_validator

class RoleEnum(str, Enum):
    ADMIN = "admin"
    DOCTOR = "doctor"
    PATIENT = "patient"
    ASSISTANT = "assistant"
    CLINIC = "clinic"

class RegisterRoleEnum(str, Enum):
    DOCTOR = "doctor"
    PATIENT = "patient"
    CLINIC = "clinic"

class UserCreate(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str
    password: str
    phone: str
    role: RegisterRoleEnum
    state: Optional[str] = None
    address: Optional[str] = None
    gender: Optional[str] = "No Especificado"
    birth_date: Optional[date] = None
    specialties: Optional[list[str]] = Field(default=None, max_length=5)
    clinic_description: Optional[str] = None
    clinic_id: Optional[int] = None
    accept_terms: bool
    accept_privacy: bool

    @model_validator(mode="after")
    def validate_birth_date(self):
        if self.role in (RegisterRoleEnum.PATIENT, RegisterRoleEnum.DOCTOR) and self.birth_date is None:
            raise ValueError("La fecha de nacimiento es obligatoria")
        if self.birth_date and self.birth_date > local_today():
            raise ValueError("La fecha de nacimiento no puede ser futura")
        return self

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, phone: str) -> str:
        import re
        cleaned = phone.strip()
        if not re.fullmatch(r"[0-9]{1,11}", cleaned):
            raise ValueError("El teléfono debe contener solo números y máximo 11 dígitos")
        return cleaned

    @field_validator("specialties")
    @classmethod
    def limit_specialties(cls, specialties: Optional[list[str]]) -> Optional[list[str]]:
        if specialties is None:
            return None
        cleaned = list(dict.fromkeys(item.strip() for item in specialties if item.strip()))
        if len(cleaned) > 5:
            raise ValueError("Un doctor puede seleccionar hasta cinco especialidades")
        return cleaned

    @field_validator("accept_terms", "accept_privacy")
    @classmethod
    def require_consent(cls, accepted: bool) -> bool:
        if not accepted:
            raise ValueError("Debe aceptar los términos y la política de privacidad")
        return accepted

class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    state: Optional[str] = None
    address: Optional[str] = None
    gender: Optional[str] = None
    birth_date: Optional[date] = None
    avatar_url: Optional[str] = None
    fcm_token: Optional[str] = None
    show_whatsapp: Optional[bool] = None

    @field_validator("birth_date")
    @classmethod
    def validate_updated_birth_date(cls, birth_date: Optional[date]) -> Optional[date]:
        if birth_date and birth_date > local_today():
            raise ValueError("La fecha de nacimiento no puede ser futura")
        return birth_date

class PasswordChange(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, password: str) -> str:
        import re
        if len(password) < 6 or not re.search(r"[A-Z]", password) or not re.search(r"[a-zA-Z]", password) or not re.search(r"[0-9]", password):
            raise ValueError("La contraseña debe tener letras, números, una mayúscula y al menos 6 caracteres")
        return password

class UserResponse(BaseModel):
    id: int
    email: EmailStr
    first_name: str
    last_name: str
    role: RoleEnum
    phone: Optional[str] = None
    show_whatsapp: bool = True
    state: Optional[str] = None
    address: Optional[str] = None
    gender: Optional[str] = None
    birth_date: Optional[date] = None
    avatar_url: Optional[str] = None
    linked_doctor_id: Optional[int] = None
    assistant_doctor_name: Optional[str] = None
    is_blocked: bool = False
    
    class Config:
        from_attributes = True
