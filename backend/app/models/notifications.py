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

from sqlalchemy import event
from sqlalchemy.engine import Connection

@event.listens_for(Notification, 'after_insert')
def receive_after_insert(mapper, connection: Connection, target: Notification):
    """
    Sends a Firebase push notification whenever a Notification is inserted into the DB.
    """
    try:
        from app.models.users import User
        from sqlalchemy import select
        # Query the user's FCM token using the current connection
        result = connection.execute(select(User.fcm_token).where(User.id == target.user_id)).fetchone()
        if result and result[0]:
            fcm_token = result[0]
            # Send push notification in a background thread to not block the DB transaction
            from app.core.firebase import send_push_notification
            import threading
            threading.Thread(
                target=send_push_notification, 
                args=(fcm_token, target.title, target.message),
                daemon=True
            ).start()
    except Exception as e:
        print(f"Error triggering push notification: {e}")
