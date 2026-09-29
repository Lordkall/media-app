from pydantic import BaseModel, Field, field_validator
from typing import List

class AvailabilityItem(BaseModel):
    date: str
    start_time: str
    end_time: str
    slot_duration_minutes: int = Field(default=30)

    @field_validator("slot_duration_minutes")
    @classmethod
    def validate_slot_duration(cls, value: int) -> int:
        if value not in (30, 60, 120):
            raise ValueError("La duración debe ser de 30, 60 o 120 minutos")
        return value

class AvailabilityUpdate(BaseModel):
    availabilities: List[AvailabilityItem]
