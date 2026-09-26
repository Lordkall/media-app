from pydantic import BaseModel, ConfigDict
from datetime import date

class AppointmentBase(BaseModel):
    doctor_id: int
    appointment_date: date

class AppointmentCreate(AppointmentBase):
    pass

class AppointmentResponse(AppointmentBase):
    id: int
    patient_id: int
    turn_number: int
    status: str

    model_config = ConfigDict(from_attributes=True)
