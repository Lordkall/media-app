from datetime import datetime, timedelta, date
from sqlalchemy import select, and_
from sqlalchemy.orm import Session
from app.models.appointments import Appointment, AppointmentStatus
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.models.doctors import Doctor

def process_vip_reminders(db: Session):
    now = datetime.utcnow()
    target_date_24h = (now + timedelta(days=1)).date()
    target_date_48h = (now + timedelta(days=2)).date()

    # Consultar citas programadas para 24h y 48h
    appointments = db.execute(
        select(Appointment).join(Doctor).where(
            Appointment.status == AppointmentStatus.SCHEDULED,
            Appointment.appointment_date.in_([target_date_24h, target_date_48h]),
            (Appointment.reminder_24h_sent == False) | (Appointment.reminder_48h_sent == False)
        )
    ).scalars().all()

    for appt in appointments:
        # Verificar suscripción VIP activa
        active_sub = db.execute(
            select(Subscription).where(
                Subscription.doctor_id == appt.doctor_id,
                Subscription.status == SubscriptionStatus.ACTIVE,
                Subscription.plan == SubscriptionPlan.SPONSORED
            )
        ).scalar_one_or_none()

        if not active_sub:
            continue # Ignorar doctores sin plan VIP

        days_diff = (appt.appointment_date - now.date()).days

        if days_diff == 1 and not appt.reminder_24h_sent:
            send_reminder_message(appt.patient, appt.doctor, "24h")
            appt.reminder_24h_sent = True
        
        elif days_diff == 2 and not appt.reminder_48h_sent:
            send_reminder_message(appt.patient, appt.doctor, "48h")
            appt.reminder_48h_sent = True

    db.commit()

def send_reminder_message(patient, doctor, timeframe):
    # Lógica de integración con WhatsApp API o Email
    print(f"Enviando recordatorio de {timeframe} a paciente ID {patient.id} para cita con Dr. ID {doctor.id}")
