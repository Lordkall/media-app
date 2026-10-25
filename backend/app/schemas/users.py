from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
from enum import Enum
from datetime import date
from app.core.demographics import local_today
from pydantic import model_validator
import base64
import binascii
import re

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
    identity_document: str
    role: RegisterRoleEnum
    state: Optional[str] = None
    address: Optional[str] = None
    gender: Optional[str] = "No Especificado"
    birth_date: Optional[date] = None
    specialties: Optional[list[str]] = Field(default=None, max_length=5)
    clinic_description: Optional[str] = None
    clinic_id: Optional[int] = None
    medical_license_number: Optional[str] = Field(default=None, max_length=60)
    medical_license_certificate_base64: Optional[str] = None
    medical_license_certificate_mime_type: Optional[str] = None
    accept_terms: bool
    accept_privacy: bool

    @model_validator(mode="after")
    def validate_birth_date(self):
        if self.role in (RegisterRoleEnum.PATIENT, RegisterRoleEnum.DOCTOR) and self.birth_date is None:
            raise ValueError("La fecha de nacimiento es obligatoria")
        if self.birth_date and self.birth_date > local_today():
            raise ValueError("La fecha de nacimiento no puede ser futura")
        return self

    @field_validator("identity_document")
    @classmethod
    def validate_identity_document(cls, value: str) -> str:
        normalized = value.strip().upper()
        if not re.fullmatch(r"[VEJGRP][0-9]{1,12}", normalized):
            raise ValueError("La cédula/RIF debe iniciar con V, E, J, G, R o P y tener hasta 12 dígitos")
        return normalized

    @field_validator("medical_license_number")
    @classmethod
    def validate_medical_license_number(cls, value: Optional[str]) -> Optional[str]:
        if value is None or not value.strip():
            return None
        normalized = value.strip().upper()
        if not re.fullmatch(r"MPPS-[0-9]{6}", normalized):
            raise ValueError("La matrícula sanitaria debe tener el formato MPPS-123456")
        return normalized

    @model_validator(mode="after")
    def validate_medical_license_certificate(self):
        encoded = self.medical_license_certificate_base64
        mime_type = self.medical_license_certificate_mime_type
        if self.role == RegisterRoleEnum.DOCTOR and not encoded and not self.medical_license_number:
            raise ValueError("Indica tu matrícula sanitaria MPPS-123456 o adjunta el certificado")
        if encoded:
            if mime_type not in ("image/jpeg", "image/png", "image/webp"):
                raise ValueError("El certificado debe ser una imagen JPG, PNG o WEBP")
            try:
                image_bytes = base64.b64decode(encoded, validate=True)
            except (binascii.Error, ValueError):
                raise ValueError("La imagen del certificado no tiene un formato válido")
            if len(image_bytes) > 4 * 1024 * 1024:
                raise ValueError("La imagen del certificado no puede superar 4 MB")
            signatures = {
                "image/jpeg": image_bytes.startswith(b"\xff\xd8\xff"),
                "image/png": image_bytes.startswith(b"\x89PNG\r\n\x1a\n"),
                "image/webp": len(image_bytes) >= 12 and image_bytes[:4] == b"RIFF" and image_bytes[8:12] == b"WEBP",
            }
            if not signatures[mime_type]:
                raise ValueError("El contenido adjunto no coincide con el formato de imagen indicado")
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
