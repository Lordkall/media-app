from sqlalchemy import String, ForeignKey, Text, Boolean, Integer, Float, Date
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import ARRAY
from app.models.base import Base
from typing import List, Optional
from datetime import date

SPECIALTIES = sorted([
    "Alergología e Inmunología Clínica",
    "Análisis Clínicos",
    "Anatomía Patológica",
    "Anestesiología",
    "Angiología",
    "Bioquímica Clínica",
    "Cardiología",
    "Cirugía Cardiovascular",
    "Cirugía General",
    "Cirugía Oral y Maxilofacial",
    "Cirugía Ortopédica",
    "Cirugía Pediátrica",
    "Cirugía Plástica, Estética y Reparadora",
    "Cirugía Torácica",
    "Cirugía Vascular",
    "Cirugía de la Mano",
    "Dermatología",
    "Endocrinología",
    "Farmacología Clínica",
    "Foniatría / Audiología",
    "Gastroenterología",
    "Genética Médica",
    "Geriatría",
    "Gerontología Médica",
    "Ginecología y Obstetricia",
    "Hematología",
    "Infectología",
    "Inmunología",
    "Medicina Familiar y Comunitaria (o Medicina General)",
    "Medicina Física y Rehabilitación",
    "Medicina Intensiva",
    "Medicina Interna",
    "Medicina Legal y Forense",
    "Medicina Nuclear",
    "Medicina Paliativa / Cuidados Paliativos",
    "Medicina Preventiva y Salud Pública",
    "Medicina de Emergencias y Urgencias",
    "Medicina del Deporte",
    "Medicina del Trabajo",
    "Microbiología y Parasitología",
    "Nefrología",
    "Neumología",
    "Neurocirugía",
    "Neurofisiología Clínica",
    "Neurología",
    "Oftalmología",
    "Oncología Médica",
    "Oncología Radioterápica",
    "Otorrinolaringología",
    "Pediatría",
    "Psiquiatría",
    "Radiodiagnóstico / Radiología",
    "Reumatología",
    "Traumatología",
    "Urología",
    "Áreas de Laboratorio y Soporte Técnico"
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

    doctor: Mapped["Doctor"] = relationship(back_populates="availabilities")
