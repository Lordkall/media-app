from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Annotated, List, Literal, Optional
from datetime import date
from decimal import Decimal

AppointmentCategory = Literal["consultation", "exam_delivery", "wound_care", "other"]
AppointmentFee = Annotated[Decimal, Field(ge=0, max_digits=12, decimal_places=2)]


class AppointmentOffer(BaseModel):
    starts_on: date
    ends_on: date
    percent: int = Field(ge=1, le=100)
    category: Literal["all", "consultation", "exam_delivery", "wound_care", "other"]

    @model_validator(mode="after")
    def validate_dates(self):
        if self.ends_on < self.starts_on:
            raise ValueError("La fecha final debe ser igual o posterior a la inicial")
        return self

class DoctorUpdate(BaseModel):
    bio: Optional[str] = Field(default=None, max_length=120)
    clinic_info: Optional[str] = None
    consultation_fee: AppointmentFee | None = None
    exam_delivery_fee: AppointmentFee | None = None
    wound_care_fee: AppointmentFee | None = None
    appointment_offer: AppointmentOffer | None = None
    show_fee_in_ves: Optional[bool] = None
    specialties: Optional[List[str]] = Field(default=None, max_length=5)
    max_patients_per_day: Optional[int] = None
    years_experience: Optional[int] = Field(default=None, ge=0, le=80)

    @field_validator("specialties")
    @classmethod
    def clean_specialties(cls, specialties: Optional[List[str]]) -> Optional[List[str]]:
        if specialties is None:
            return None
        cleaned = list(dict.fromkeys(item.strip() for item in specialties if item.strip()))
        if len(cleaned) > 5:
            raise ValueError("Un doctor puede seleccionar hasta cinco especialidades")
        return cleaned

class DoctorResponse(BaseModel):
    id: int
    user_id: int
    specialties: List[str]
    bio: Optional[str]
    clinic_info: Optional[str]
    is_approved: bool
    is_featured: bool
    is_sponsored: bool
    consultation_fee: Optional[float]
    exam_delivery_fee: AppointmentFee | None = None
    wound_care_fee: AppointmentFee | None = None
    appointment_offer: AppointmentOffer | None = None
    show_fee_in_ves: bool = False
    medical_license_number: Optional[str] = None
    rating: float
    total_reviews: int
    years_experience: int = 0
    max_patients_per_day: int
    is_vip: Optional[bool] = False # A computed field for the frontend
    clinic_id: Optional[int] = None
    requested_clinic_id: Optional[int] = None
    clinic_join_status: Optional[str] = None
    
    class Config:
        from_attributes = True


class DoctorRatingCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
