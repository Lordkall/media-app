import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.models.base import Base
from app.models.users import User, RoleEnum
from app.models.doctors import Doctor
import os

# Usamos la base por defecto de postgres para facilitar la prueba
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql+asyncpg://postgres:12345@127.0.0.1:5432/postgres"
)

engine = create_async_engine(SQLALCHEMY_DATABASE_URL, echo=True)
async_session_maker = async_sessionmaker(engine, expire_on_commit=False)

async def init_db():
    print("Iniciando creación de tablas...")
    async with engine.begin() as conn:
        # Crea todas las tablas. En producción usaríamos Alembic.
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    
    print("Insertando usuarios iniciales...")
    async with async_session_maker() as session:
        # ── Administrador ──
        admin = User(
            email="admin@saludnow.com",
            first_name="Admin",
            last_name="Sistema",
            phone="04121234567",
            hashed_password="123456",
            role=RoleEnum.ADMIN
        )

        # ── Paciente ──
        paciente = User(
            email="paciente@saludnow.com",
            first_name="María",
            last_name="González",
            phone="04161234567",
            hashed_password="123456",
            role=RoleEnum.PATIENT
        )

        # ── Doctores (usuarios) ──
        doc_users = [
            User(email="dr.mendoza@saludnow.com", first_name="Carlos", last_name="Mendoza",
                 phone="04141000001", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dra.herrera@saludnow.com", first_name="Ana", last_name="Herrera",
                 phone="04141000002", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dr.perez@saludnow.com", first_name="Roberto", last_name="Pérez",
                 phone="04141000003", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dra.lopez@saludnow.com", first_name="Valentina", last_name="López",
                 phone="04141000004", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dr.silva@saludnow.com", first_name="Andrés", last_name="Silva",
                 phone="04141000005", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dra.martinez@saludnow.com", first_name="Gabriela", last_name="Martínez",
                 phone="04141000006", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dr.ramirez@saludnow.com", first_name="Luis", last_name="Ramírez",
                 phone="04141000007", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dra.torres@saludnow.com", first_name="Isabella", last_name="Torres",
                 phone="04141000008", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dr.castro@saludnow.com", first_name="Diego", last_name="Castro",
                 phone="04141000009", hashed_password="123456", role=RoleEnum.DOCTOR),
            User(email="dra.rojas@saludnow.com", first_name="Camila", last_name="Rojas",
                 phone="04141000010", hashed_password="123456", role=RoleEnum.DOCTOR),
        ]

        session.add_all([admin, paciente] + doc_users)
        await session.flush()  # Generar IDs

        # ── Perfiles de Doctor ──
        doctors = [
            # 🟡 PATROCINADOS (aparecen primero)
            Doctor(is_approved=True, 
                user_id=doc_users[0].id,
                specialties=["Cardiología"],
                bio="Cardiólogo con 15 años de experiencia en el Hospital Central de Caracas. Especialista en ecocardiografía y cateterismo cardíaco.",
                clinic_info="Centro Médico Caracas, Piso 3, Consultorio 301",
                is_sponsored=True, sponsored_priority=1,
                is_featured=True,
                consultation_fee=80.0, rating=4.9, total_reviews=234
            ),
            Doctor(is_approved=True, 
                user_id=doc_users[1].id,
                specialties=["Dermatología"],
                bio="Dermatóloga certificada. Experta en dermatología estética, acné y tratamientos láser.",
                clinic_info="Clínica Bella Piel, Altamira",
                is_sponsored=True, sponsored_priority=2,
                is_featured=False,
                consultation_fee=65.0, rating=4.8, total_reviews=189
            ),

            # 🟢 DESTACADOS (aparecen después de patrocinados)
            Doctor(is_approved=True, 
                user_id=doc_users[2].id,
                specialties=["Pediatría"],
                bio="Pediatra neonatólogo con atención integral para niños desde recién nacidos hasta 14 años. Control de crecimiento y vacunación.",
                clinic_info="Hospital de Niños J.M. de los Ríos",
                is_sponsored=False, sponsored_priority=99,
                is_featured=True,
                consultation_fee=50.0, rating=4.9, total_reviews=312
            ),
            Doctor(is_approved=True, 
                user_id=doc_users[3].id,
                specialties=["Ginecología y Obstetricia"],
                bio="Ginecóloga obstetra. Control prenatal, planificación familiar y cirugía ginecológica mínimamente invasiva.",
                clinic_info="Centro Clínico La Trinidad, Torre C",
                is_sponsored=False, sponsored_priority=99,
                is_featured=True,
                consultation_fee=70.0, rating=4.7, total_reviews=156
            ),

            # 🔵 DOCTORES REGULARES
            Doctor(is_approved=True, 
                user_id=doc_users[4].id,
                specialties=["Neurología"],
                bio="Neurólogo clínico. Diagnóstico y tratamiento de migrañas, epilepsia y trastornos del sueño.",
                clinic_info="Policlínica Metropolitana, Consultorio 510",
                is_sponsored=False, sponsored_priority=99,
                is_featured=False,
                consultation_fee=75.0, rating=4.6, total_reviews=98
            ),
            Doctor(is_approved=True, 
                user_id=doc_users[5].id,
                specialties=["Nutrición"],
                bio="Nutricionista clínica y deportiva. Planes personalizados para pérdida de peso, diabetes y alimentación saludable.",
                clinic_info="Consultorio privado, Las Mercedes",
                is_sponsored=False, sponsored_priority=99,
                is_featured=False,
                consultation_fee=45.0, rating=4.5, total_reviews=87
            ),
            Doctor(is_approved=True, 
                user_id=doc_users[6].id,
                specialties=["Traumatología", "Cirugía Ortopédica"],
                bio="Traumatólogo deportivo. Artroscopias de rodilla y hombro, fracturas y rehabilitación de lesiones deportivas.",
                clinic_info="Centro Médico Docente La Trinidad",
                is_sponsored=False, sponsored_priority=99,
                is_featured=False,
                consultation_fee=70.0, rating=4.4, total_reviews=76
            ),
            Doctor(is_approved=True, 
                user_id=doc_users[7].id,
                specialties=["Oftalmología"],
                bio="Oftalmóloga especializada en cirugía refractiva (LASIK), glaucoma y cataratas.",
                clinic_info="Instituto Oftalmológico del Este",
                is_sponsored=False, sponsored_priority=99,
                is_featured=False,
                consultation_fee=60.0, rating=4.3, total_reviews=64
            ),
            Doctor(is_approved=True, 
                user_id=doc_users[8].id,
                specialties=["Medicina Familiar y Comunitaria (o Medicina General)", "Medicina Interna"],
                bio="Médico internista con enfoque integral. Chequeos preventivos, control de hipertensión y diabetes.",
                clinic_info="Ambulatorio del Sur, Consultorio 2",
                is_sponsored=False, sponsored_priority=99,
                is_featured=False,
                consultation_fee=35.0, rating=4.7, total_reviews=203
            ),
            Doctor(is_approved=True, 
                user_id=doc_users[9].id,
                specialties=["Psiquiatría"],
                bio="Psiquiatra clínica. Tratamiento de ansiedad, depresión y trastornos del ánimo. Terapia combinada con psicofármacos.",
                clinic_info="Clínica Santa Sofía, Torre Sur, Piso 8",
                is_sponsored=False, sponsored_priority=99,
                is_featured=False,
                consultation_fee=55.0, rating=4.6, total_reviews=112
            ),
        ]

        session.add_all(doctors)
        await session.flush()  # Generar IDs de doctores

        # ── Suscripciones y Notificaciones Iniciales ──
        from app.models.subscriptions import Subscription, SubscriptionPlan, SubscriptionStatus
        from app.models.notifications import Notification, NotificationType
        from datetime import datetime, timedelta, timezone

        now = datetime.now(timezone.utc)

        # Doctor Mendoza: Suscripción Patrocinada Activa (expira en 25 días)
        sub1 = Subscription(
            doctor_id=doctors[0].id,
            plan=SubscriptionPlan.SPONSORED,
            status=SubscriptionStatus.ACTIVE,
            start_date=now - timedelta(days=5),
            end_date=now + timedelta(days=25),
            grace_end_date=now + timedelta(days=28),
            auto_renew=True
        )

        # Doctora Herrera: Suscripción por vencer en 2 días (para probar alerta de 3 días)
        sub2 = Subscription(
            doctor_id=doctors[1].id,
            plan=SubscriptionPlan.SPONSORED,
            status=SubscriptionStatus.ACTIVE,
            start_date=now - timedelta(days=28),
            end_date=now + timedelta(days=2),
            grace_end_date=now + timedelta(days=5),
            auto_renew=True
        )

        # Doctor Pérez: Suscripción Destacada en Periodo de Gracia
        sub3 = Subscription(
            doctor_id=doctors[2].id,
            plan=SubscriptionPlan.FEATURED,
            status=SubscriptionStatus.GRACE_PERIOD,
            start_date=now - timedelta(days=31),
            end_date=now - timedelta(days=1),
            grace_end_date=now + timedelta(days=2),
            auto_renew=False
        )

        session.add_all([sub1, sub2, sub3])

        # Notificación al Admin sobre la suscripción de Doctor Mendoza
        notif_admin = Notification(
            user_id=admin.id,
            type=NotificationType.NEW_SUBSCRIPTION,
            title="Nueva Suscripción de Doctor",
            message="El Dr. Carlos Mendoza se ha suscrito al Plan Patrocinado ($99.99 USD).",
            is_read=False,
            action_url="/subscriptions/admin"
        )

        # Notificación a la Dra. Herrera sobre renovación próxima
        notif_doc = Notification(
            user_id=doc_users[1].id,
            type=NotificationType.RENEWAL_REMINDER,
            title="Suscripción por Vencer",
            message="Tu suscripción al Plan Patrocinado vencerá en 2 días. Renueva ahora para mantener tu posicionamiento prioritaria.",
            is_read=False,
            action_url="/subscribe"
        )

        session.add_all([notif_admin, notif_doc])
        
        # ── Crear Perfil de Paciente ──
        from app.models.patients import Patient
        from app.models.appointments import Appointment, AppointmentStatus
        from datetime import date
        
        paciente_profile = Patient(
            user_id=paciente.id,
            contact_phone="04161234567"
        )
        session.add(paciente_profile)
        await session.flush()
        
        # ── Citas de Prueba para Overbooking ──
        # Ponemos el limite del Dr Mendoza a 3 para probar rápido
        doctors[0].max_patients_per_day = 3
        
        today = date.today()
        # Creamos 3 citas para el Dr Mendoza hoy
        citas_hoy = [
            Appointment(patient_id=paciente_profile.id, doctor_id=doctors[0].id, appointment_date=today, turn_number=1, status=AppointmentStatus.SCHEDULED),
            Appointment(patient_id=paciente_profile.id, doctor_id=doctors[0].id, appointment_date=today, turn_number=2, status=AppointmentStatus.SCHEDULED),
            Appointment(patient_id=paciente_profile.id, doctor_id=doctors[0].id, appointment_date=today, turn_number=3, status=AppointmentStatus.SCHEDULED)
        ]
        session.add_all(citas_hoy)

        await session.commit()

    print("\n[OK] Base de datos inicializada correctamente.")
    print("\n--- Usuarios creados ---")
    print("  Admin:    admin@saludnow.com      / 123456")
    print("  Paciente: paciente@saludnow.com   / 123456")
    print("\n--- Doctores creados (todos con password 123456) ---")
    print("  [PATROCINADO #1] Dr. Carlos Mendoza    - Cardiologia")
    print("  [PATROCINADO #2] Dra. Ana Herrera       - Dermatologia")
    print("  [DESTACADO]      Dr. Roberto Perez      - Pediatria")
    print("  [DESTACADO]      Dra. Valentina Lopez   - Ginecologia")
    print("                   Dr. Andres Silva        - Neurologia")
    print("                   Dra. Gabriela Martinez  - Nutricion")
    print("                   Dr. Luis Ramirez        - Traumatologia")
    print("                   Dra. Isabella Torres    - Oftalmologia")
    print("                   Dr. Diego Castro        - Medicina General")
    print("                   Dra. Camila Rojas       - Psiquiatria")

if __name__ == "__main__":
    import sys
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(init_db())
