"""
Verificador periódico de suscripciones.
Ejecuta la revisión de vencimientos, notificaciones a 3 días y aplicación de periodo de gracia / revocación.
"""
import asyncio
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from datetime import datetime
from app.core.database import async_session_maker
from app.core.subscription_service import SubscriptionService

async def run_subscription_check():
    """Ejecuta una ronda de verificación de suscripciones."""
    async with async_session_maker() as db:
        print(f"[{datetime.now()}] Ejecutando verificación de suscripciones...")
        # 1. Notificar vencimiento a 3 días
        notified = await SubscriptionService.check_expiring_subscriptions(db)
        print(f"  - Doctores notificados por vencer en 3 días: {notified}")
        
        # 2. Procesar periodo de gracia / revocación
        grace_count, revoked_count = await SubscriptionService.process_grace_and_expiration(db)
        print(f"  - Suscripciones entraron en gracia: {grace_count}")
        print(f"  - Suscripciones revocadas: {revoked_count}")
        print(f"[{datetime.now()}] Verificación completada.")

if __name__ == "__main__":
    asyncio.run(run_subscription_check())
