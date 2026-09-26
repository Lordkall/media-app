from sqlalchemy import String, ForeignKey, Text, Boolean, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
from typing import List, Optional
from app.models.subscriptions import Subscription

class Clinic(Base):
    __tablename__ = "clinics"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True)
    
    # Clinic info
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    # Approval
    is_approved: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="clinic_profile", foreign_keys="[Clinic.user_id]")
    doctors: Mapped[List["Doctor"]] = relationship(back_populates="clinic")
    subscriptions: Mapped[List["Subscription"]] = relationship(back_populates="clinic")
