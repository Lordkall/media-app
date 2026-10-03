from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.api.v1.router import api_router
import os

from contextlib import asynccontextmanager
from app.core.database import engine
from sqlalchemy import text

import asyncio
from datetime import datetime, timedelta

async def bcv_updater_loop():
    while True:
        try:
            # First, update the rate immediately
            from app.tasks.bcv_scraper import update_db_with_rate
            await update_db_with_rate()
            
            now = datetime.now()
            # Calculate next midnight
            next_midnight = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
            sleep_seconds = (next_midnight - now).total_seconds()
            
            # Wait until midnight for the next update
            await asyncio.sleep(sleep_seconds)
        except asyncio.CancelledError:
            break
        except Exception as e:
            print(f"Error en tarea programada de BCV: {e}")
            await asyncio.sleep(3600)  # Retry in an hour if there's an unexpected error

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Migration on startup
    try:
        async with engine.begin() as conn:
            from app.models.support import SupportTicket, TicketMessage
            from app.models.base import Base
            await conn.run_sync(Base.metadata.create_all)
            await conn.execute(text("ALTER TABLE users ALTER COLUMN avatar_url TYPE TEXT;"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR;"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_data TEXT;"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_content_type VARCHAR(100);"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP WITH TIME ZONE;"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_accepted_at TIMESTAMP WITH TIME ZONE;"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_version VARCHAR(30);"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_version VARCHAR(30);"))
            await conn.execute(text("ALTER TABLE clinics ADD COLUMN IF NOT EXISTS specialties JSON;"))
            await conn.execute(text("ALTER TABLE clinics ADD COLUMN IF NOT EXISTS contact_phone_2 VARCHAR(20);"))
            await conn.execute(text("ALTER TABLE clinics ADD COLUMN IF NOT EXISTS invite_code VARCHAR(32);"))
            await conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_clinics_invite_code ON clinics (invite_code) WHERE invite_code IS NOT NULL;"))
            await conn.execute(text("ALTER TABLE doctors ADD COLUMN IF NOT EXISTS requested_clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL;"))
            await conn.execute(text("ALTER TABLE doctors ADD COLUMN IF NOT EXISTS clinic_join_status VARCHAR(20);"))
            await conn.execute(text("ALTER TABLE appointments ALTER COLUMN patient_id DROP NOT NULL;"))
            await conn.execute(text("ALTER TABLE appointments ADD COLUMN IF NOT EXISTS patient_first_name VARCHAR(100);"))
            await conn.execute(text("ALTER TABLE appointments ADD COLUMN IF NOT EXISTS patient_last_name VARCHAR(100);"))
            await conn.execute(text("ALTER TABLE appointments ADD COLUMN IF NOT EXISTS patient_phone VARCHAR(30);"))
            await conn.execute(text("ALTER TABLE appointments ADD COLUMN IF NOT EXISTS appointment_reason VARCHAR(500);"))
            await conn.execute(text("ALTER TABLE appointments ADD COLUMN IF NOT EXISTS booking_source VARCHAR(20) NOT NULL DEFAULT 'online';"))
            await conn.execute(text("ALTER TABLE availabilities ADD COLUMN IF NOT EXISTS slot_duration_minutes INTEGER NOT NULL DEFAULT 30;"))
            await conn.execute(text("ALTER TABLE appointments ADD COLUMN IF NOT EXISTS appointment_start_minutes INTEGER;"))
            await conn.execute(text("ALTER TABLE appointments ADD COLUMN IF NOT EXISTS appointment_duration_minutes INTEGER NOT NULL DEFAULT 30;"))
            await conn.execute(text("UPDATE appointments a SET appointment_start_minutes = (split_part(v.start_time, ':', 1)::INTEGER * 60 + split_part(v.start_time, ':', 2)::INTEGER + (a.turn_number - 1) * 30) FROM availabilities v WHERE v.doctor_id = a.doctor_id AND v.date = a.appointment_date AND a.appointment_start_minutes IS NULL;"))
            await conn.execute(text("ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS deleted_by_user BOOLEAN DEFAULT FALSE;"))
            await conn.execute(text("ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS deleted_by_admin BOOLEAN DEFAULT FALSE;"))
            await conn.execute(text("ALTER TABLE ticket_messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;"))
            await conn.execute(text("DROP INDEX IF EXISTS uq_appointments_active_slot;"))
            await conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS uq_appointments_active_start ON appointments (doctor_id, appointment_date, appointment_start_minutes) WHERE status <> 'CANCELLED' AND appointment_start_minutes IS NOT NULL;"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE;"))
            await conn.execute(text("ALTER TABLE appointments ADD COLUMN IF NOT EXISTS reminder_whatsapp_sent BOOLEAN NOT NULL DEFAULT FALSE;"))
    except Exception as e:
        print(f"Migration error (might already be TEXT): {e}")

    # Keep the PostgreSQL notification enum in sync with NotificationType.
    try:
        notification_values = [
            "NEW_SUBSCRIPTION",
            "RENEWAL_REMINDER",
            "GRACE_PERIOD_WARNING",
            "SUBSCRIPTION_REVOKED",
            "SUBSCRIPTION_RENEWED",
            "APPOINTMENT_CREATED",
            "APPOINTMENT_CANCELLED",
            "DOCTOR_REGISTERED",
            "DOCTOR_APPROVED",
            "SUPPORT_MESSAGE",
            "CLINIC_JOIN_REQUEST",
            "CLINIC_JOIN_APPROVED",
            "new_subscription",
            "renewal_reminder",
            "grace_period_warning",
            "subscription_revoked",
            "subscription_renewed",
            "appointment_created",
            "appointment_cancelled",
            "doctor_registered",
            "doctor_approved",
            "support_message",
            "clinic_join_request",
            "clinic_join_approved",
        ]
        async with engine.begin() as conn:
            for value in notification_values:
                await conn.execute(
                    text(
                        "ALTER TYPE notificationtype "
                        f"ADD VALUE IF NOT EXISTS '{value}'"
                    )
                )
    except Exception as e:
        print(f"Notification enum migration error: {e}")

    # SQLAlchemy persists Python Enum member names (for example, "CLINIC")
    # in PostgreSQL. The legacy clinic migration added the lowercase value,
    # which does not match the value used by the ORM during registration.
    if engine.dialect.name == "postgresql":
        try:
            async with engine.begin() as conn:
                await conn.execute(
                    text("ALTER TYPE roleenum ADD VALUE IF NOT EXISTS 'CLINIC'")
                )
        except Exception as e:
            print(f"Role enum migration error: {e}")

        # Keep the database enum aligned with clinic subscription plans. The
        # labels must be committed before /subscriptions/renew inserts a row.
        try:
            async with engine.begin() as conn:
                await conn.execute(
                    text("ALTER TYPE subscriptionplan ADD VALUE IF NOT EXISTS 'CLINIC_BASIC'")
                )
                await conn.execute(
                    text("ALTER TYPE subscriptionplan ADD VALUE IF NOT EXISTS 'CLINIC_VIP'")
                )
        except Exception as e:
            print(f"Subscription plan enum migration error: {e}")

    # Auto-migrate subscriptions table
    try:
        async with engine.begin() as conn:
            sub_columns = [
                "clinic_id INTEGER REFERENCES clinics(id)",
                "auto_renew BOOLEAN DEFAULT TRUE",
                "created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()",
                "updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()",
                "reference_number VARCHAR",
                "screenshot_base64 TEXT",
                "amount_bs FLOAT",
            ]
            for col_def in sub_columns:
                try:
                    await conn.execute(text(f"ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS {col_def}"))
                except Exception:
                    pass
            await conn.execute(
                text("ALTER TABLE subscriptions ALTER COLUMN doctor_id DROP NOT NULL")
            )
            print("Subscriptions migration done.")
    except Exception as e:
        print(f"Subscriptions migration error: {e}")

    # Auto-migrate doctors table
    try:
        async with engine.begin() as conn:
            doctors_columns = [
                "clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL",
                "max_patients_per_day INTEGER DEFAULT 5",
                "sponsored_priority INTEGER DEFAULT 99",
                "is_sponsored BOOLEAN DEFAULT FALSE",
                "is_featured BOOLEAN DEFAULT FALSE",
                "is_approved BOOLEAN DEFAULT FALSE",
                "rating FLOAT DEFAULT 0.0",
                "total_reviews INTEGER DEFAULT 0",
                "consultation_fee FLOAT",
                "bio TEXT",
                "clinic_info TEXT",
            ]
            for col_def in doctors_columns:
                try:
                    await conn.execute(text(f"ALTER TABLE doctors ADD COLUMN IF NOT EXISTS {col_def}"))
                except Exception:
                    pass
            print("Doctors migration done.")
    except Exception as e:
        print(f"Doctors migration error: {e}")

        
    # Start background tasks
    bcv_task = asyncio.create_task(bcv_updater_loop())
    from app.tasks.reminders import appointment_reminders_loop
    reminders_task = asyncio.create_task(appointment_reminders_loop())
    
    yield
    
    # Cleanup on shutdown
    bcv_task.cancel()
    reminders_task.cancel()

app = FastAPI(title="MedIA Backend", version="1.0.0", lifespan=lifespan)

from app.core.firebase import init_firebase
init_firebase()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permits all origins (including saludnow.site)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")

os.makedirs("uploads/avatars", exist_ok=True)
app.mount("/api/v1/uploads", StaticFiles(directory="uploads"), name="uploads")

# No-cache middleware for Flutter JS files to prevent stale browser cache
NO_CACHE_FILES = {"main.dart.js", "flutter_bootstrap.js", "flutter_service_worker.js", "index.html", "manifest.json"}

@app.middleware("http")
async def no_cache_for_js(request, call_next):
    response = await call_next(request)
    path = request.url.path.lstrip("/")
    filename = path.split("/")[-1] if path else ""
    if filename in NO_CACHE_FILES or not filename:
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response

app.mount("/", StaticFiles(directory="static", html=True), name="flutter_web")

from fastapi import Request
from fastapi.responses import JSONResponse
import traceback

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "traceback": traceback.format_exc()}
    )
