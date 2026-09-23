from fastapi import APIRouter
from app.api.v1.endpoints import appointments
from app.api.v1.endpoints import auth
from app.api.v1.endpoints import password_reset
from app.api.v1.endpoints import users
from app.api.v1.endpoints import doctors
from app.api.v1.endpoints import subscriptions

api_router = APIRouter()
api_router.include_router(appointments.router, prefix="/appointments", tags=["appointments"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(doctors.router, prefix="/doctors", tags=["doctors"])
api_router.include_router(password_reset.router, prefix="/password-reset", tags=["Password Reset"])
api_router.include_router(subscriptions.router, prefix="/subscriptions", tags=["subscriptions"])
