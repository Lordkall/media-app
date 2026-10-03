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
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.services.twilio_service import send_whatsapp_appointment_reminder

async def send_appointment_reminders_async():
    """
    Revisa todas las citas agendadas y envía recordatorios:
    - 48h: Notificación interna y push a todos los pacientes.
    - 24h: Notificación interna y push a todos los pacientes.
    - WhatsApp (23-24 horas antes de la cita, una sola vez): Exclusivo para citas de doctores VIP (plan SPONSORED).
    """
    async with async_session_maker() as session:
        # La hora local de las citas y turnos está en hora de Caracas
        now = datetime.now(ZoneInfo("America/Caracas")).replace(tzinfo=None)

        # Margen exacto para recordatorio 23-24 horas
        time_24h_min = now + timedelta(hours=23)
        time_24h_max = now + timedelta(hours=24, minutes=15)

        # Margen para 48h: entre 46h y 50h desde ahora
        time_48h_min = now + timedelta(hours=46)
        time_48h_max = now + timedelta(hours=50)

        # Buscar citas agendadas desde hoy en adelante
        query = (
            select(Appointment)
            .options(
                joinedload(Appointment.doctor).joinedload(Doctor.user),
                joinedload(Appointment.doctor).joinedload(Doctor.availabilities),
                joinedload(Appointment.doctor).joinedload(Doctor.subscriptions),
                joinedload(Appointment.patient).joinedload(Patient.user)
            )
            .where(
                Appointment.status == AppointmentStatus.SCHEDULED,
                Appointment.appointment_date >= now.date(),
                (
                    (Appointment.reminder_24h_sent == False) |
                    (Appointment.reminder_48h_sent == False) |
                    (Appointment.reminder_whatsapp_sent == False)
                )
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

            time_str = appt_datetime.strftime("%I:%M %p")
            date_str = appt.appointment_date.strftime("%d/%m/%Y")
            days_diff = (appt.appointment_date - now.date()).days

            # ----------------------------------------------------
            # 1. Recordatorio Push/App de 48 horas (Todos los pacientes)
            # ----------------------------------------------------
            if not appt.reminder_48h_sent:
                is_48h_window = (time_48h_min <= appt_datetime <= time_48h_max) or (days_diff == 2 and now.hour >= 8)

                if is_48h_window:
                    notif = Notification(
                        user_id=patient_user.id,
                        type=NotificationType.RENEWAL_REMINDER,
                        title="Recordatorio de Cita Médica (48h)",
                        message=f"Recuerda que tienes una cita médica con {doc_name} programada para el {date_str} (Turno #{appt.turn_number})."
                    )
                    session.add(notif)
                    appt.reminder_48h_sent = True
                    print(f"[RECORDATORIO] Recordatorio 48h generado para paciente {patient_user.id}, cita #{appt.id}")

            # ----------------------------------------------------
            # 2. Recordatorio Push/App de 24 horas (Todos los pacientes)
            # ----------------------------------------------------
            is_24h_window = (time_24h_min <= appt_datetime <= time_24h_max) or (days_diff == 1 and now.hour >= 8)
            if not appt.reminder_24h_sent and is_24h_window:
                notif = Notification(
                    user_id=patient_user.id,
                    type=NotificationType.RENEWAL_REMINDER,
                    title="Recordatorio de Cita Médica (24h)",
                    message=f"¡Tu cita es mañana! Tienes cita con {doc_name} el {date_str} a las {time_str} (Turno #{appt.turn_number}). Por favor asiste puntual."
                )
                session.add(notif)
                appt.reminder_24h_sent = True
                print(f"[RECORDATORIO] Recordatorio 24h generado para paciente {patient_user.id}, cita #{appt.id}")

            # ----------------------------------------------------
            # 3. Recordatorio WhatsApp (Rango 23-24 horas, una sola vez, SOLO citas de Doctor VIP)
            # ----------------------------------------------------
            if not appt.reminder_whatsapp_sent:
                hours_until_appt = (appt_datetime - now).total_seconds() / 3600.0

                # Debe estar en el rango de 23 a 24 horas antes de la cita
                if 23.0 <= hours_until_appt <= 24.5:
                    # Verificar si el doctor es VIP
                    is_doctor_vip = False
                    if doctor:
                        if getattr(doctor, "is_sponsored", False):
                            is_doctor_vip = True
                        elif doctor.subscriptions:
                            for sub in doctor.subscriptions:
                                if sub.status == SubscriptionStatus.ACTIVE and sub.plan in [
                                    SubscriptionPlan.SPONSORED,
                                    SubscriptionPlan.CLINIC_VIP,
                                ]:
                                    is_doctor_vip = True
                                    break

                    if is_doctor_vip:
                        patient_phone = (
                            appt.patient_phone or
                            getattr(appt.patient, "contact_phone", None) or
                            getattr(patient_user, "phone", None)
                        )

                        if patient_phone:
                            patient_name = f"{patient_user.first_name} {patient_user.last_name}".strip()
                            print(f"[WHATSAPP VIP] Enviando recordatorio 23-24h a {patient_name} ({patient_phone})...")
                            sent = send_whatsapp_appointment_reminder(
                                to_phone=patient_phone,
                                patient_name=patient_name,
                                doctor_name=doc_name,
                                appointment_date_str=date_str,
                                turn_number=appt.turn_number,
                                appointment_time_str=time_str
                            )
                            if sent:
                                appt.reminder_whatsapp_sent = True
                                print(f"[WHATSAPP VIP] Enviado exitosamente para cita #{appt.id}")
                            else:
                                print(f"[WHATSAPP VIP] Falló envío para cita #{appt.id}")

        await session.commit()

async def appointment_reminders_loop():
    """
    Bucle en segundo plano que corre periódicamente cada 15 minutos
    para verificar y enviar los recordatorios de citas.
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
