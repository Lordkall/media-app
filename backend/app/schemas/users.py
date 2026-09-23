from pydantic import BaseModel, EmailStr
from typing import Optional
from enum import Enum

class RoleEnum(str, Enum):
    ADMIN = "admin"
    DOCTOR = "doctor"
    PATIENT = "patient"
    ASSISTANT = "assistant"

class UserCreate(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str
    password: str
    phone: str
    role: RoleEnum
    state: Optional[str] = None
    address: Optional[str] = None
    gender: Optional[str] = "No Especificado"
    specialties: Optional[list[str]] = []

class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    state: Optional[str] = None
    address: Optional[str] = None
    gender: Optional[str] = None
    avatar_url: Optional[str] = None
    fcm_token: Optional[str] = None

class PasswordChange(BaseModel):
    current_password: str
    new_password: str

class UserResponse(BaseModel):
    id: int
    email: EmailStr
    first_name: str
    last_name: str
    role: RoleEnum
    phone: Optional[str] = None
    state: Optional[str] = None
    address: Optional[str] = None
    gender: Optional[str] = None
    avatar_url: Optional[str] = None
    linked_doctor_id: Optional[int] = None
    
    class Config:
        from_attributes = True
