from pydantic import BaseModel, ConfigDict, Field, model_validator
from datetime import date
from typing import Optional
from app.core.demographics import local_today

class AppointmentBase(BaseModel):
    doctor_id: int
    appointment_date: date
    turn_number: int = Field(gt=0)
    appointment_reason: Optional[str] = None
    reason: Optional[str] = None
    is_for_dependent: bool = False
    dependent_name: Optional[str] = Field(default=None, max_length=200)
    dependent_birth_date: Optional[date] = None
    dependent_relationship: Optional[str] = Field(default=None, max_length=40)
    dependent_gender: Optional[str] = Field(default=None, max_length=30)

    @model_validator(mode="after")
    def validate_dependent(self):
        if self.is_for_dependent:
            if not self.dependent_name or not self.dependent_name.strip():
                raise ValueError("El nombre del dependiente es obligatorio")
            if not self.dependent_birth_date:
                raise ValueError("La fecha de nacimiento del dependiente es obligatoria")
            if self.dependent_birth_date > local_today():
                raise ValueError("La fecha de nacimiento no puede ser futura")
            if not self.dependent_relationship:
                raise ValueError("Selecciona el parentesco")
            if self.dependent_relationship not in {
                "Hijo", "Hija", "Abuelo", "Abuela", "Padre", "Madre", "Tutor", "Representante legal"
            }:
                raise ValueError("El parentesco seleccionado no es válido")
        return self

class AppointmentCreate(AppointmentBase):
    pass

class AppointmentResponse(AppointmentBase):
    id: int
    patient_id: Optional[int] = None
    turn_number: int
    status: str
    appointment_reason: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)
