from datetime import datetime, timezone
from typing import Optional
from sqlalchemy import String, ForeignKey, Enum, Boolean, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
import enum


class NotificationType(str, enum.Enum):
    NEW_SUBSCRIPTION = "new_subscription"
    RENEWAL_REMINDER = "renewal_reminder"
    GRACE_PERIOD_WARNING = "grace_period_warning"
    SUBSCRIPTION_REVOKED = "subscription_revoked"
    SUBSCRIPTION_RENEWED = "subscription_renewed"
    APPOINTMENT_CREATED = "appointment_created"
    APPOINTMENT_CANCELLED = "appointment_cancelled"
    DOCTOR_REGISTERED = "doctor_registered"
    DOCTOR_APPROVED = "doctor_approved"


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    type: Mapped[NotificationType] = mapped_column(Enum(NotificationType), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    action_url: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    # Relaciones
    user: Mapped["User"] = relationship(back_populates="notifications")
