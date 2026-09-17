from pydantic import BaseModel, ConfigDict
from datetime import datetime

class AppointmentBase(BaseModel):
    doctor_id: int
    start_time_utc: datetime
    end_time_utc: datetime

class AppointmentCreate(AppointmentBase):
    pass

class AppointmentResponse(AppointmentBase):
    id: int
    patient_id: int
    status: str

    model_config = ConfigDict(from_attributes=True)
