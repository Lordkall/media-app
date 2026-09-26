from fastapi import APIRouter
from app.api.v1.endpoints import appointments
from app.api.v1.endpoints import auth
from app.api.v1.endpoints import password_reset
from app.api.v1.endpoints import users
from app.api.v1.endpoints import doctors
from app.api.v1.endpoints import subscriptions
from app.api.v1.endpoints import admin
from app.api.v1.endpoints import assistants
from app.api.v1.endpoints import upload
from app.api.v1.endpoints import support
from app.api.v1.endpoints import clinics

api_router = APIRouter()
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(appointments.router, prefix="/appointments", tags=["appointments"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(doctors.router, prefix="/doctors", tags=["doctors"])
api_router.include_router(password_reset.router, prefix="/password-reset", tags=["Password Reset"])
api_router.include_router(subscriptions.router, prefix="/subscriptions", tags=["subscriptions"])
api_router.include_router(assistants.router, prefix="/assistants", tags=["assistants"])
api_router.include_router(upload.router, prefix="/upload", tags=["upload"])
api_router.include_router(support.router, prefix="/support", tags=["support"])
api_router.include_router(clinics.router, prefix="/clinics", tags=["clinics"])

from app.api.v1.endpoints import ws
api_router.include_router(ws.router, prefix="/ws", tags=["websocket"])
