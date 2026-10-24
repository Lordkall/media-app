import asyncio
from app.tasks.reminders import send_appointment_reminders_async

def process_vip_reminders(db=None):
    """
    Función de compatibilidad para procesar recordatorios automáticos de citas.
    Ejecuta la tarea asíncrona principal de recordatorios.
    """
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            return asyncio.create_task(send_appointment_reminders_async())
        else:
            return loop.run_until_complete(send_appointment_reminders_async())
    except Exception as e:
        print(f"[VIP REMINDERS] Error al procesar recordatorios: {e}")
