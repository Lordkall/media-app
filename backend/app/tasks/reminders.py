import asyncio
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from app.core.database import async_session_maker
from app.models.appointments import Appointment, AppointmentStatus
from app.models.doctors import Doctor
from app.models.patients import Patient
from app.models.notifications import Notification, NotificationType

async def send_appointment_reminders_async():
    """
    Revisa todas las citas agendadas y envía recordatorios de 24h y 48h
    a todos los pacientes registrados mediante notificación en la app y Push Notification.
    """
    async with async_session_maker() as session:
        # La hora local de las citas y turnos está en hora de Caracas
        now = datetime.now(ZoneInfo("America/Caracas")).replace(tzinfo=None)

        # Margen para 24h: entre 22h y 26h desde ahora (o si la cita es mañana)
        time_24h_min = now + timedelta(hours=22)
        time_24h_max = now + timedelta(hours=26)

        # Margen para 48h: entre 46h y 50h desde ahora
        time_48h_min = now + timedelta(hours=46)
        time_48h_max = now + timedelta(hours=50)

        # Buscar citas agendadas desde hoy en adelante que no tengan enviado 24h o 48h
        query = (
            select(Appointment)
            .options(
                joinedload(Appointment.doctor).joinedload(Doctor.user),
                joinedload(Appointment.doctor).joinedload(Doctor.availabilities),
                joinedload(Appointment.patient).joinedload(Patient.user)
            )
            .where(
                Appointment.status == AppointmentStatus.SCHEDULED,
                Appointment.appointment_date >= now.date(),
                (Appointment.reminder_24h_sent == False) | (Appointment.reminder_48h_sent == False)
            )
        )

        result = await session.execute(query)
        appointments = result.scalars().unique().all()

        for appt in appointments:
            if not appt.patient or not appt.patient.user:
                continue

            patient_user = appt.patient.user
            doctor = appt.doctor
            doc_user = doctor.user if doctor else None
            doc_title = "Dr(a)."
            if doc_user:
                is_fem = (doc_user.gender or "").strip().lower() in ["femenino", "femenina"]
                doc_title = "la Dra." if is_fem else "el Dr."
                doc_name = f"{doc_title} {doc_user.first_name} {doc_user.last_name}".strip()
            else:
                doc_name = "su médico"

            # Calcular la fecha/hora exacta de inicio de la cita
            availability = None
            if doctor and doctor.availabilities:
                availability = next((a for a in doctor.availabilities if a.date == appt.appointment_date), None)

            start_hour, start_minute = (8, 0)
            if availability:
                try:
                    start_hour, start_minute = map(int, availability.start_time[:5].split(":"))
                except Exception:
                    pass

            if appt.appointment_start_minutes is not None:
                appt_datetime = datetime.combine(
                    appt.appointment_date, datetime.min.time()
                ) + timedelta(minutes=appt.appointment_start_minutes)
            else:
                appt_datetime = datetime.combine(
                    appt.appointment_date, datetime.min.time()
                ) + timedelta(
                    hours=start_hour,
                    minutes=start_minute + (appt.turn_number - 1) * 30,
                )

            # 1. Recordatorio de 48 horas
            if not appt.reminder_48h_sent:
                # Comprobar si está en ventana de 48h o si faltan 2 días y ya es hora diurna
                days_diff = (appt.appointment_date - now.date()).days
                is_48h_window = (time_48h_min <= appt_datetime <= time_48h_max) or (days_diff == 2 and now.hour >= 8)

                if is_48h_window:
                    notif = Notification(
                        user_id=patient_user.id,
                        type=NotificationType.RENEWAL_REMINDER,
                        title="Recordatorio de Cita Médica (48h)",
                        message=f"Recuerda que tienes una cita médica con {doc_name} programada para el {appt.appointment_date.strftime('%d/%m/%Y')} (Turno #{appt.turn_number})."
                    )
                    session.add(notif)
                    appt.reminder_48h_sent = True
                    print(f"[RECORDATORIO] Recordatorio 48h generado para paciente {patient_user.id}, cita #{appt.id}")

            # 2. Recordatorio de 24 horas
            if not appt.reminder_24h_sent:
                days_diff = (appt.appointment_date - now.date()).days
                is_24h_window = (time_24h_min <= appt_datetime <= time_24h_max) or (days_diff == 1 and now.hour >= 8)

                if is_24h_window:
                    notif = Notification(
                        user_id=patient_user.id,
                        type=NotificationType.RENEWAL_REMINDER,
                        title="Recordatorio de Cita Médica (24h)",
                        message=f"¡Tu cita es mañana! Tienes cita con {doc_name} el {appt.appointment_date.strftime('%d/%m/%Y')} (Turno #{appt.turn_number}). Por favor asiste puntual."
                    )
                    session.add(notif)
                    appt.reminder_24h_sent = True
                    print(f"[RECORDATORIO] Recordatorio 24h generado para paciente {patient_user.id}, cita #{appt.id}")

        await session.commit()

async def appointment_reminders_loop():
    """
    Bucle en segundo plano que corre periódicamente para verificar
    y enviar los recordatorios de citas.
    """
    while True:
        try:
            await send_appointment_reminders_async()
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"[RECORDATORIO ERROR] Error en bucle de recordatorios: {e}")

        # Ejecutar cada 15 minutos
        await asyncio.sleep(900)
