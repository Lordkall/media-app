from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.clinics import Clinic
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription, SubscriptionPlan, SubscriptionStatus


async def active_clinic_subscription(db: AsyncSession, clinic_id: int):
    return await db.scalar(
        select(Subscription)
        .where(
            Subscription.clinic_id == clinic_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.grace_end_date > datetime.now(timezone.utc),
            Subscription.plan.in_(
                [SubscriptionPlan.CLINIC_BASIC, SubscriptionPlan.CLINIC_VIP]
            ),
        )
        .order_by(Subscription.end_date.desc())
    )


def clinic_doctor_limit(plan: SubscriptionPlan) -> int:
    return 15 if plan == SubscriptionPlan.CLINIC_VIP else 10


async def clinic_doctor_count(db: AsyncSession, clinic_id: int) -> int:
    return int(
        await db.scalar(
            select(func.count(Doctor.id)).where(Doctor.clinic_id == clinic_id)
        )
        or 0
    )


async def clinic_has_capacity(db: AsyncSession, clinic_id: int, plan: SubscriptionPlan) -> bool:
    return await clinic_doctor_count(db, clinic_id) < clinic_doctor_limit(plan)


async def active_clinic_for_user(db: AsyncSession, user_id: int):
    clinic = await db.scalar(select(Clinic).where(Clinic.user_id == user_id))
    if not clinic:
        return None, None
    return clinic, await active_clinic_subscription(db, clinic.id)
