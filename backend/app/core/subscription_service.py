"""
Servicio de suscripciones: toda la logica de negocio para crear, verificar,
renovar y revocar suscripciones de doctores.
"""
from datetime import datetime, timedelta, timezone
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.users import User, RoleEnum
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription, SubscriptionPlan, SubscriptionStatus
from app.models.notifications import Notification, NotificationType


PLAN_PRICES = {
    SubscriptionPlan.FEATURED: 10.0,    # Plan Básico ($10/mes)
    SubscriptionPlan.SPONSORED: 30.0,   # Plan VIP ($30/mes)
}

PLAN_LABELS = {
    SubscriptionPlan.FEATURED: "Básico ($10)",
    SubscriptionPlan.SPONSORED: "VIP ($30)",
}

SUBSCRIPTION_DAYS = 30
REMINDER_DAYS_BEFORE = 3
GRACE_PERIOD_DAYS = 3


def _now():
    return datetime.now(timezone.utc)


class SubscriptionService:
    PLAN_PRICES = PLAN_PRICES
    PLAN_LABELS = PLAN_LABELS

    @staticmethod
    async def create_subscription(session: AsyncSession, doctor_id: int, plan: SubscriptionPlan) -> Subscription:
        return await create_subscription(session, doctor_id, plan)

    @staticmethod
    async def check_expiring_subscriptions(session: AsyncSession):
        return await check_expiring_subscriptions(session)

    @staticmethod
    async def process_grace_and_expiration(session: AsyncSession):
        grace_count = await process_grace_periods(session)
        revoked_count = await revoke_expired_subscriptions(session)
        return grace_count, revoked_count

    @staticmethod
    async def renew_subscription(session: AsyncSession, subscription_id: int) -> Subscription:
        return await renew_subscription(session, subscription_id)

    @staticmethod
    async def get_active_subscription(session: AsyncSession, doctor_id: int):
        return await get_active_subscription(session, doctor_id)


async def create_subscription(session: AsyncSession, doctor_id: int, plan: SubscriptionPlan) -> Subscription:
    """
    Crea una nueva suscripcion para un doctor.
    - Activa el flag correspondiente en el perfil del doctor.
    - Notifica al admin.
    """
    now = _now()
    end_date = now + timedelta(days=31)
    grace_end = end_date + timedelta(days=GRACE_PERIOD_DAYS)

    sub = Subscription(
        doctor_id=doctor_id,
        plan=plan,
        status=SubscriptionStatus.ACTIVE,
        start_date=now,
        end_date=end_date,
        grace_end_date=grace_end,
        auto_renew=True,
        created_at=now,
        updated_at=now,
    )
    session.add(sub)

    # Activar flag en doctor
    doctor = await session.get(Doctor, doctor_id, options=[joinedload(Doctor.user)])
    if doctor:
        if plan == SubscriptionPlan.SPONSORED:
            doctor.is_sponsored = True
            doctor.sponsored_priority = 1
        elif plan == SubscriptionPlan.FEATURED:
            doctor.is_featured = True

        # Notificar al admin
        admins = (await session.execute(
            select(User).where(User.role == RoleEnum.ADMIN)
        )).scalars().all()

        plan_label = PLAN_LABELS[plan]
        is_female = getattr(doctor.user, 'gender', '') in ('F', 'Femenino', 'femenino')
        doc_name = f"Dr{'a' if is_female else ''}. {doctor.user.first_name} {doctor.user.last_name}"

        for admin in admins:
            notif = Notification(
                user_id=admin.id,
                type=NotificationType.NEW_SUBSCRIPTION,
                title="Nueva suscripcion",
                message=f"{doc_name} se ha suscrito al plan {plan_label} (${PLAN_PRICES[plan]:.0f}/mes).",
                is_read=False,
                action_url=None,
                created_at=now,
            )
            session.add(notif)

    await session.flush()
    return sub


async def check_expiring_subscriptions(session: AsyncSession) -> int:
    """
    Busca suscripciones ACTIVAS que vencen en los proximos REMINDER_DAYS_BEFORE dias.
    Crea notificacion de recordatorio al doctor.
    Retorna cantidad de recordatorios creados.
    """
    now = _now()
    reminder_threshold = now + timedelta(days=REMINDER_DAYS_BEFORE)

    query = (
        select(Subscription)
        .options(joinedload(Subscription.doctor).joinedload(Doctor.user))
        .where(
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.end_date <= reminder_threshold,
            Subscription.end_date > now,
        )
    )
    result = await session.execute(query)
    subs = result.scalars().unique().all()

    count = 0
    for sub in subs:
        # Verificar que no exista ya un recordatorio reciente (ultimas 24h)
        existing = await session.execute(
            select(Notification).where(
                Notification.user_id == sub.doctor.user.id,
                Notification.type == NotificationType.RENEWAL_REMINDER,
                Notification.created_at >= now - timedelta(hours=24),
            )
        )
        if existing.scalars().first():
            continue

        days_left = (sub.end_date - now).days
        plan_label = PLAN_LABELS[sub.plan]

        notif = Notification(
            user_id=sub.doctor.user.id,
            type=NotificationType.RENEWAL_REMINDER,
            title="Renovar suscripcion",
            message=f"Tu plan {plan_label} vence en {days_left} dia(s). Renueva ahora para mantener tu visibilidad.",
            is_read=False,
            action_url="/subscribe",
            created_at=now,
        )
        session.add(notif)
        count += 1

    await session.flush()
    return count


async def process_grace_periods(session: AsyncSession) -> int:
    """
    Mueve suscripciones ACTIVE vencidas a GRACE_PERIOD.
    Notifica al doctor.
    """
    now = _now()

    query = (
        select(Subscription)
        .options(joinedload(Subscription.doctor).joinedload(Doctor.user))
        .where(
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.end_date <= now,
        )
    )
    result = await session.execute(query)
    subs = result.scalars().unique().all()

    count = 0
    for sub in subs:
        sub.status = SubscriptionStatus.GRACE_PERIOD
        sub.updated_at = now

        days_grace = (sub.grace_end_date - now).days

        notif = Notification(
            user_id=sub.doctor.user.id,
            type=NotificationType.GRACE_PERIOD_WARNING,
            title="Periodo de gracia activo",
            message=f"Tu plan {PLAN_LABELS[sub.plan]} ha vencido. Tienes {days_grace} dia(s) para renovar antes de perder tu visibilidad.",
            is_read=False,
            action_url="/subscribe",
            created_at=now,
        )
        session.add(notif)
        count += 1

    await session.flush()
    return count


async def revoke_expired_subscriptions(session: AsyncSession) -> int:
    """
    Revoca suscripciones cuyo periodo de gracia ha terminado.
    Desactiva flags de patrocinado/destacado en el doctor.
    """
    now = _now()

    query = (
        select(Subscription)
        .options(joinedload(Subscription.doctor).joinedload(Doctor.user))
        .where(
            Subscription.status == SubscriptionStatus.GRACE_PERIOD,
            Subscription.grace_end_date <= now,
        )
    )
    result = await session.execute(query)
    subs = result.scalars().unique().all()

    count = 0
    for sub in subs:
        sub.status = SubscriptionStatus.EXPIRED
        sub.updated_at = now

        doctor = sub.doctor
        if sub.plan == SubscriptionPlan.SPONSORED:
            doctor.is_sponsored = False
            doctor.sponsored_priority = 99
        elif sub.plan == SubscriptionPlan.FEATURED:
            doctor.is_featured = False

        notif = Notification(
            user_id=doctor.user.id,
            type=NotificationType.SUBSCRIPTION_REVOKED,
            title="Suscripcion revocada",
            message=f"Tu plan {PLAN_LABELS[sub.plan]} ha sido revocado por falta de pago. Suscribete nuevamente para recuperar tu visibilidad.",
            is_read=False,
            action_url="/subscribe",
            created_at=now,
        )
        session.add(notif)
        count += 1

    await session.flush()
    return count


async def renew_subscription(session: AsyncSession, subscription_id: int) -> Subscription:
    """
    Renueva una suscripcion existente por 30 dias mas.
    """
    now = _now()

    sub = await session.get(
        Subscription, subscription_id,
        options=[joinedload(Subscription.doctor).joinedload(Doctor.user)]
    )
    if not sub:
        raise ValueError("Suscripcion no encontrada")

    # Extender fechas desde hoy (no desde el vencimiento anterior)
    sub.end_date = now + timedelta(days=31)
    sub.grace_end_date = sub.end_date + timedelta(days=GRACE_PERIOD_DAYS)
    sub.status = SubscriptionStatus.ACTIVE
    sub.updated_at = now

    # Reactivar flags
    doctor = sub.doctor
    if sub.plan == SubscriptionPlan.SPONSORED:
        doctor.is_sponsored = True
        doctor.sponsored_priority = 1
    elif sub.plan == SubscriptionPlan.FEATURED:
        doctor.is_featured = True

    # Notificar al doctor
    notif_doctor = Notification(
        user_id=doctor.user.id,
        type=NotificationType.SUBSCRIPTION_RENEWED,
        title="Suscripcion renovada",
        message=f"Tu plan {PLAN_LABELS[sub.plan]} ha sido renovado exitosamente hasta {sub.end_date.strftime('%d/%m/%Y')}.",
        is_read=False,
        created_at=now,
    )
    session.add(notif_doctor)

    # Notificar al admin
    admins = (await session.execute(
        select(User).where(User.role == RoleEnum.ADMIN)
    )).scalars().all()

    is_female = getattr(doctor.user, 'gender', '') in ('F', 'Femenino', 'femenino')
    doc_name = f"Dr{'a' if is_female else ''}. {doctor.user.first_name} {doctor.user.last_name}"
    for admin in admins:
        notif_admin = Notification(
            user_id=admin.id,
            type=NotificationType.SUBSCRIPTION_RENEWED,
            title="Suscripcion renovada",
            message=f"{doc_name} ha renovado su plan {PLAN_LABELS[sub.plan]}.",
            is_read=False,
            created_at=now,
        )
        session.add(notif_admin)

    await session.flush()
    return sub


async def get_active_subscription(session: AsyncSession, doctor_id: int):
    """Obtiene la suscripcion activa o en gracia de un doctor."""
    query = (
        select(Subscription)
        .where(
            Subscription.doctor_id == doctor_id,
            Subscription.status.in_([SubscriptionStatus.ACTIVE, SubscriptionStatus.GRACE_PERIOD]),
        )
        .order_by(Subscription.created_at.desc())
        .limit(1)
    )
    result = await session.execute(query)
    return result.scalars().first()


async def run_all_checks(session: AsyncSession) -> dict:
    """Ejecuta todas las verificaciones de suscripciones."""
    reminders = await check_expiring_subscriptions(session)
    grace = await process_grace_periods(session)
    revoked = await revoke_expired_subscriptions(session)
    await session.commit()
    return {
        "reminders_sent": reminders,
        "moved_to_grace": grace,
        "revoked": revoked,
    }
