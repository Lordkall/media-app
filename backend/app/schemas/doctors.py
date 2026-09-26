from pydantic import BaseModel
from typing import List, Optional
from datetime import date

class DoctorUpdate(BaseModel):
    bio: Optional[str] = None
    clinic_info: Optional[str] = None
    consultation_fee: Optional[float] = None
    specialties: Optional[List[str]] = None
    max_patients_per_day: Optional[int] = None

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
    rating: float
    total_reviews: int
    max_patients_per_day: int
    is_vip: Optional[bool] = False # A computed field for the frontend
    
    class Config:
        from_attributes = True
