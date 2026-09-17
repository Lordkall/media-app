from datetime import datetime, timedelta
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker, joinedload
import sys, os

# Ensure the app module can be found when this script is run
base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
if base_path not in sys.path:
    sys.path.append(base_path)

from app.models.appointments import Appointment, AppointmentStatus
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan
from app.models.notifications import Notification, NotificationType

SYNC_DB_URL = "postgresql+psycopg2://postgres:12345@127.0.0.1:5432/postgres"

def send_appointment_reminders():
    print("Ejecutando tarea de recordatorios...")
    engine = create_engine(SYNC_DB_URL)
    Session = sessionmaker(bind=engine)
    
    with Session() as session:
        now = datetime.utcnow()
        # Rango para 24 horas: entre 23 y 25 horas desde ahora
        time_24h_min = now + timedelta(hours=23)
        time_24h_max = now + timedelta(hours=25)
        
        # Rango para 48 horas: entre 47 y 49 horas desde ahora
        time_48h_min = now + timedelta(hours=47)
        time_48h_max = now + timedelta(hours=49)
        
        # Obtener todas las citas programadas futuras
        appointments = session.execute(
            select(Appointment).options(
                joinedload(Appointment.doctor).joinedload(Doctor.user),
                joinedload(Appointment.patient)
            ).where(
                Appointment.status == AppointmentStatus.SCHEDULED,
                Appointment.appointment_date >= now.date()
            )
        ).scalars().unique().all()
        
        for appt in appointments:
            # Check if doctor is VIP
            sub = session.execute(
                select(Subscription).where(
                    Subscription.doctor_id == appt.doctor_id,
                    Subscription.status == SubscriptionStatus.ACTIVE,
                    Subscription.plan == SubscriptionPlan.SPONSORED
                )
            ).scalars().first()
            
            if not sub:
                continue # Doctor no es VIP
                
            # Calculamos la fecha y hora de la cita. 
            appt_datetime = datetime.combine(appt.appointment_date, datetime.min.time()) + timedelta(hours=8 + appt.turn_number * 0.5)
            
            # Revisar recordatorio 48h
            if time_48h_min <= appt_datetime <= time_48h_max and not appt.reminder_48h_sent:
                notif = Notification(
                    user_id=appt.patient.user_id,
                    type=NotificationType.SYSTEM,
                    title="Recordatorio de Cita (48h)",
                    message=f"Recuerda que tienes una cita con el Dr(a). {appt.doctor.user.first_name} {appt.doctor.user.last_name} en 48 horas."
                )
                session.add(notif)
                appt.reminder_48h_sent = True
                print(f"Recordatorio de 48h enviado para cita {appt.id}")
                
            # Revisar recordatorio 24h
            if time_24h_min <= appt_datetime <= time_24h_max and not appt.reminder_24h_sent:
                notif = Notification(
                    user_id=appt.patient.user_id,
                    type=NotificationType.SYSTEM,
                    title="Recordatorio de Cita (24h)",
                    message=f"Recuerda que tienes una cita con el Dr(a). {appt.doctor.user.first_name} {appt.doctor.user.last_name} en 24 horas."
                )
                session.add(notif)
                appt.reminder_24h_sent = True
                print(f"Recordatorio de 24h enviado para cita {appt.id}")
                
        session.commit()
    print("Tarea de recordatorios finalizada.")
