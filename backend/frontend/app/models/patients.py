from sqlalchemy import String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
from typing import List

class Patient(Base):
    __tablename__ = "patients"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True)
    contact_phone: Mapped[str] = mapped_column(String(20), nullable=True)
    medical_history: Mapped[str] = mapped_column(String, nullable=True)

    # Relaciones
    user: Mapped["User"] = relationship(back_populates="patient_profile")
    appointments: Mapped[List["Appointment"]] = relationship(back_populates="patient")
