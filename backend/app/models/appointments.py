from datetime import datetime, date
from sqlalchemy import ForeignKey, DateTime, Date, Enum, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
import enum

class AppointmentStatus(str, enum.Enum):
    SCHEDULED = "scheduled"
    CANCELLED = "cancelled"
    COMPLETED = "completed"

class Appointment(Base):
    __tablename__ = "appointments"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    patient_id: Mapped[int] = mapped_column(ForeignKey("patients.id"), index=True)
    doctor_id: Mapped[int] = mapped_column(ForeignKey("doctors.id"), index=True)
    
    # Citas por turno
    appointment_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    turn_number: Mapped[int] = mapped_column(Integer, nullable=False)
    
    status: Mapped[AppointmentStatus] = mapped_column(Enum(AppointmentStatus), default=AppointmentStatus.SCHEDULED, nullable=False)
    reminder_24h_sent: Mapped[bool] = mapped_column(default=False, nullable=False)
    reminder_48h_sent: Mapped[bool] = mapped_column(default=False, nullable=False)

    # Relaciones
    patient: Mapped["Patient"] = relationship(back_populates="appointments")
    doctor: Mapped["Doctor"] = relationship(back_populates="appointments")
