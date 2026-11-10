"""Periodic reminders for subscriptions that are close to expiration."""

import asyncio

from app.core.database import async_session_maker
from app.core.subscription_service import SubscriptionService


async def subscription_renewal_reminder_loop() -> None:
    """Check often; the service enforces reminders, grace periods (3 days), and revokes expired subscriptions."""
    while True:
        try:
            async with async_session_maker() as session:
                res = await SubscriptionService.run_all_checks(session)
                if any(res.values()):
                    print(f"[SUSCRIPCIONES] Verificación completada: {res}")
        except asyncio.CancelledError:
            break
        except Exception as exc:
            print(f"[SUSCRIPCIONES] Error al verificar suscripciones: {exc}")

        try:
            await asyncio.sleep(15 * 60)
        except asyncio.CancelledError:
            break
