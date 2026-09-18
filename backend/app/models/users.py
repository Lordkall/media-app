from typing import Optional, List
from sqlalchemy import String, Enum, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
import enum

class RoleEnum(str, enum.Enum):
    ADMIN = "admin"
    DOCTOR = "doctor"
    PATIENT = "patient"
    ASSISTANT = "assistant"

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    phone: Mapped[str] = mapped_column(String(20), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[RoleEnum] = mapped_column(Enum(RoleEnum), nullable=False)
    state: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    gender: Mapped[Optional[str]] = mapped_column(String(20), default="No Especificado")
    avatar_url: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    session_token: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    fcm_token: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    linked_doctor_id: Mapped[Optional[int]] = mapped_column(ForeignKey("doctors.id", ondelete="CASCADE"), nullable=True)
    
    # Relaciones
    doctor_profile: Mapped[Optional["Doctor"]] = relationship(back_populates="user", foreign_keys="[Doctor.user_id]")
    patient_profile: Mapped[Optional["Patient"]] = relationship(back_populates="user")
    notifications: Mapped[List["Notification"]] = relationship(back_populates="user")

