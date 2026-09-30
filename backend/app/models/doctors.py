from sqlalchemy import String, ForeignKey, Text, Boolean, Integer, Float, Date
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import ARRAY
from app.models.base import Base
from typing import List, Optional
from datetime import date

SPECIALTIES = sorted([
    "Alergología",
    "Anestesiología Dental",
    "Anestesiología y Reanimación",
    "Audiología",
    "Cardiología Hemodinámica y Electrofisiología",
    "Cirugía Cardiovascular",
    "Cirugía General y del Aparato Digestivo",
    "Cirugía Oral y Maxilofacial",
    "Cirugía Ortopédica y Traumatología",
    "Cirugía Pediátrica",
    "Cirugía Plástica, Estética y Reparadora",
    "Cirugía Torácica",
    "Dermatología Médico-Quirúrgica y Venereología",
    "Endodoncia",
    "Endocrinología y Nutrición",
    "Fisioterapia Avanzada",
    "Gastroenterología y Hepatología",
    "Genética Médica",
    "Geriatría",
    "Ginecología y Obstetricia",
    "Medicina Materno-Fetal",
    "Reproducción Asistida",
    "Hematología y Hemoterapia",
    "Infectología",
    "Medicina del Trabajo",
    "Medicina Familiar y Comunitaria",
    "Medicina Física y Rehabilitación",
    "Medicina Intensiva",
    "Medicina Interna",
    "Medicina Legal y Forense",
    "Medicina Nuclear",
    "Medicina Preventiva y Salud Pública",
    "Nefrología",
    "Neumonología",
    "Neurocirugía",
    "Neurología",
    "Neuropediatría",
    "Nutrición y Dietética",
    "Odontología de Salud Pública",
    "Odontología General",
    "Odontopediatría",
    "Oftalmología",
    "Oncología Médica",
    "Oncología Radioterápica",
    "Ortodoncia",
    "Otorrinolaringología",
    "Patología Oral y Maxilofacial",
    "Pediatría Neonatología",
    "Periodoncia",
    "Prostodoncia",
    "Psiquiatría Infanto-Juvenil",
    "Radiodiagnóstico",
    "Radiología Oral y Maxilofacial",
    "Reumatología",
    "Urología",
])

class Doctor(Base):
    __tablename__ = "doctors"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True)
    specialties: Mapped[List[str]] = mapped_column(ARRAY(String), nullable=False, default=list)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    clinic_info: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Aprobación por Administrador
    is_approved: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Sistema de destacados/patrocinados
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_sponsored: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    sponsored_priority: Mapped[int] = mapped_column(Integer, default=99, nullable=False)

    # Métricas
    consultation_fee: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rating: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    total_reviews: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    max_patients_per_day: Mapped[int] = mapped_column(Integer, default=5, nullable=False)

    clinic_id: Mapped[Optional[int]] = mapped_column(ForeignKey("clinics.id", ondelete="SET NULL"), nullable=True)
    requested_clinic_id: Mapped[Optional[int]] = mapped_column(ForeignKey("clinics.id", ondelete="SET NULL"), nullable=True)
    clinic_join_status: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    # Relaciones
    user: Mapped["User"] = relationship(back_populates="doctor_profile", foreign_keys="[Doctor.user_id]")
    clinic: Mapped[Optional["Clinic"]] = relationship(back_populates="doctors")
    availabilities: Mapped[List["Availability"]] = relationship(back_populates="doctor")
    appointments: Mapped[List["Appointment"]] = relationship(back_populates="doctor")
    subscriptions: Mapped[List["Subscription"]] = relationship(back_populates="doctor")

class Availability(Base):
    __tablename__ = "availabilities"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    doctor_id: Mapped[int] = mapped_column(ForeignKey("doctors.id"), index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False) # Fecha especifica
    start_time: Mapped[str] = mapped_column(String(5), nullable=False) # ej: "09:00"
    end_time: Mapped[str] = mapped_column(String(5), nullable=False)   # ej: "17:00"
    slot_duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=30, server_default="30")

    doctor: Mapped["Doctor"] = relationship(back_populates="availabilities")
