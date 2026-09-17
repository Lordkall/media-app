from datetime import datetime
from sqlalchemy import String, ForeignKey, Enum, Boolean, DateTime, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base
import enum


class SubscriptionPlan(str, enum.Enum):
    BASIC = "basic"             # Plan basico
    FEATURED = "featured"       # Aparece como Destacado
    SPONSORED = "sponsored"     # Aparece como Patrocinado (prioridad maxima)


class SubscriptionStatus(str, enum.Enum):
    PENDING_APPROVAL = "pending_approval" # Pendiente de aprobación por el Admin
    ACTIVE = "active"
    GRACE_PERIOD = "grace_period"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    doctor_id: Mapped[int] = mapped_column(ForeignKey("doctors.id"), index=True, nullable=False)
    plan: Mapped[SubscriptionPlan] = mapped_column(Enum(SubscriptionPlan), nullable=False)
    status: Mapped[SubscriptionStatus] = mapped_column(
        Enum(SubscriptionStatus), default=SubscriptionStatus.ACTIVE, nullable=False
    )

    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    grace_end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    auto_renew: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    # Relaciones
    doctor: Mapped["Doctor"] = relationship(back_populates="subscriptions")
