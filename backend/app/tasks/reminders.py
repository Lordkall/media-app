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
    - 48h: Notificación interna y push para pacientes con cuenta registrada.
    - 24h: Notificación interna y push para pacientes con cuenta registrada.
    - WhatsApp (24 horas antes de la cita): Exclusivo para citas de doctores VIP (plan SPONSORED / CLINIC_VIP).
      Aplica tanto para citas online como manuales registradas por el doctor.
    """
    async with async_session_maker() as session:
        # La hora local de las citas y turnos está en hora de Caracas
        now = datetime.now(ZoneInfo("America/Caracas")).replace(tzinfo=None)

        # Margen para 24h: citas que ocurren mañana o hoy
        time_24h_min = now + timedelta(hours=20)
        time_24h_max = now + timedelta(hours=28)

        # Margen para 48h: entre 44h y 52h desde ahora
        time_48h_min = now + timedelta(hours=44)
        time_48h_max = now + timedelta(hours=52)

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
            patient_user = appt.patient.user if (appt.patient and appt.patient.user) else None

            # Obtener nombre del paciente (tanto en citas online como manuales)
            if patient_user:
                patient_name = f"{patient_user.first_name} {patient_user.last_name}".strip()
            else:
                first = (appt.patient_first_name or "").strip()
                last = (appt.patient_last_name or "").strip()
                patient_name = f"{first} {last}".strip() or "Paciente"

            # Obtener teléfono del paciente
            patient_phone = (
                appt.patient_phone or
                (getattr(appt.patient, "contact_phone", None) if appt.patient else None) or
                (getattr(patient_user, "phone", None) if patient_user else None)
            )

            doctor = appt.doctor
            doc_user = doctor.user if doctor else None
            doc_title = "Dr(a)."
            if doc_user:
                is_fem = (doc_user.gender or "").strip().lower() in ["femenino", "femenina"]
                doc_title = "la Dra." if is_fem else "el Dr."
                doc_name = f"{doc_title} {doc_user.first_name} {doc_user.last_name}".strip()
            else:
                doc_name = "su médico"

            # Determinar si el doctor tiene Plan VIP Patrocinado
            is_doc_vip = False
            if doctor:
                if getattr(doctor, "is_sponsored", False):
                    is_doc_vip = True
                elif doctor.subscriptions:
                    is_doc_vip = any(
                        s.status == SubscriptionStatus.ACTIVE and s.plan in (SubscriptionPlan.SPONSORED, SubscriptionPlan.CLINIC_VIP)
                        for s in doctor.subscriptions
                    )
                if not is_doc_vip and doctor.clinic_id:
                    from app.core.clinic_access import active_clinic_subscription
                    clinic_sub = await active_clinic_subscription(session, doctor.clinic_id)
                    if clinic_sub and clinic_sub.plan in (SubscriptionPlan.CLINIC_VIP, SubscriptionPlan.SPONSORED):
                        is_doc_vip = True

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
            # 1. Recordatorio Push/App de 48 horas (Pacientes con cuenta)
            # ----------------------------------------------------
            if patient_user and not appt.reminder_48h_sent:
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
            # 2. Recordatorio Push/App de 24 horas (Pacientes con cuenta)
            # ----------------------------------------------------
            is_24h_window = (
                (time_24h_min <= appt_datetime <= time_24h_max) or
                (days_diff == 1) or
                (days_diff == 0 and appt_datetime > now)
            )

            if patient_user and not appt.reminder_24h_sent and is_24h_window:
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
            # 3. Recordatorio WhatsApp de 24 horas (Exclusivo Plan VIP Patrocinado)
            # ----------------------------------------------------
            if not appt.reminder_whatsapp_sent and (is_24h_window or appt.reminder_24h_sent):
                if not is_doc_vip:
                    # El doctor tiene plan básico: no incluye recordatorios automáticos por WhatsApp
                    print(f"[WHATSAPP RECORDATORIO] Cita #{appt.id} no enviada por WhatsApp: doctor ID {doctor.id if doctor else 'N/A'} no tiene Plan VIP Patrocinado.")
                elif patient_phone:
                    print(f"[WHATSAPP RECORDATORIO] Enviando recordatorio 24h a {patient_name} ({patient_phone}) para cita #{appt.id} (Doctor VIP ID {doctor.id})...")
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
                        print(f"[WHATSAPP RECORDATORIO] Enviado exitosamente para cita #{appt.id}")
                    else:
                        print(f"[WHATSAPP RECORDATORIO] Falló envío para cita #{appt.id}")
                else:
                    print(f"[WHATSAPP RECORDATORIO] Paciente sin teléfono registrado para cita #{appt.id}")

        await session.commit()

async def appointment_reminders_loop():
    """
    Bucle en segundo plano que corre periódicamente cada 15 minutos
    para verificar y enviar los recordatorios de citas.
    """
    while True:
        try:
            await send_appointment_reminders_async()
            async with async_session_maker() as session:
                from app.api.v1.endpoints.appointments import auto_complete_expired_appointments
                await auto_complete_expired_appointments(session)
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"[RECORDATORIO ERROR] Error en bucle de recordatorios: {e}")

        # Ejecutar cada 15 minutos
        await asyncio.sleep(900)
