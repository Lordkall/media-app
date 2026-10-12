from pydantic import BaseModel, ConfigDict, Field
from datetime import date
from typing import Optional

class AppointmentBase(BaseModel):
    doctor_id: int
    appointment_date: date
    turn_number: int = Field(gt=0)
    appointment_reason: Optional[str] = None
    reason: Optional[str] = None

class AppointmentCreate(AppointmentBase):
    pass

class AppointmentResponse(AppointmentBase):
    id: int
    patient_id: Optional[int] = None
    turn_number: int
    status: str
    appointment_reason: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)
