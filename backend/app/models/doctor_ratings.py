from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, SmallInteger, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class DoctorRating(Base):
    __tablename__ = "doctor_ratings"
    __table_args__ = (
        UniqueConstraint("doctor_id", "patient_id", name="uq_doctor_rating_patient"),
        CheckConstraint("rating >= 1 AND rating <= 5", name="ck_doctor_rating_range"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    doctor_id: Mapped[int] = mapped_column(
        ForeignKey("doctors.id", ondelete="CASCADE"), nullable=False, index=True
    )
    patient_id: Mapped[int] = mapped_column(
        ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True
    )
    rating: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class DoctorPatientHistory(Base):
    """Distinct registered patients with at least one completed visit."""

    __tablename__ = "doctor_patient_history"

    doctor_id: Mapped[int] = mapped_column(
        ForeignKey("doctors.id", ondelete="CASCADE"), primary_key=True
    )
    patient_id: Mapped[int] = mapped_column(
        ForeignKey("patients.id", ondelete="CASCADE"), primary_key=True
    )


class ClinicRating(Base):
    __tablename__ = "clinic_ratings"
    __table_args__ = (
        UniqueConstraint("clinic_id", "patient_id", name="uq_clinic_rating_patient"),
        CheckConstraint("rating >= 1 AND rating <= 5", name="ck_clinic_rating_range"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    clinic_id: Mapped[int] = mapped_column(
        ForeignKey("clinics.id", ondelete="CASCADE"), nullable=False, index=True
    )
    patient_id: Mapped[int] = mapped_column(
        ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True
    )
    rating: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
