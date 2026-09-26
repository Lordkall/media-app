from pydantic import BaseModel
from typing import List

class AvailabilityItem(BaseModel):
    date: str
    start_time: str
    end_time: str

class AvailabilityUpdate(BaseModel):
    availabilities: List[AvailabilityItem]
