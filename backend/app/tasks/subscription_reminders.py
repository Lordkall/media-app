"""Periodic reminders for subscriptions that are close to expiration."""

import asyncio

from app.core.database import async_session_maker
from app.core.subscription_service import SubscriptionService


async def subscription_renewal_reminder_loop() -> None:
    """Check often; the service enforces a 24-hour interval per subscription."""
    while True:
        try:
            async with async_session_maker() as session:
                sent = await SubscriptionService.check_expiring_subscriptions(session)
                await session.commit()
                if sent:
                    print(f"[SUSCRIPCIONES] Recordatorios enviados: {sent}")
        except asyncio.CancelledError:
            break
        except Exception as exc:
            print(f"[SUSCRIPCIONES] Error al enviar recordatorios: {exc}")

        try:
            await asyncio.sleep(15 * 60)
        except asyncio.CancelledError:
            break
