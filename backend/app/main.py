from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.router import api_router

from contextlib import asynccontextmanager
from app.core.database import engine
from sqlalchemy import text

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Migration on startup
    try:
        async with engine.begin() as conn:
            await conn.execute(text("ALTER TABLE users ALTER COLUMN avatar_url TYPE TEXT;"))
    except Exception as e:
        print(f"Migration error (might already be TEXT): {e}")
    yield

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

import flet.fastapi as flet_fastapi
import sys
import os

# Add backend root to sys.path so frontend can import app.models
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from frontend.main import main as flet_main

import tempfile
upload_dir_path = os.path.join(tempfile.gettempdir(), "saludnow_uploads")
os.makedirs(upload_dir_path, exist_ok=True)

if os.getenv("DISABLE_FLET", "False").lower() not in ("true", "1", "yes"):
    app.mount("/", flet_fastapi.app(
        flet_main, 
        assets_dir=os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend", "assets")),
        upload_dir=upload_dir_path,
        secret_key=os.getenv("FLET_SECRET_KEY", "saludnow_super_secret_key_12345")
    ))
else:
    @app.get("/")
    def read_root():
        return {"status": "Backend API is running. Flet frontend is disabled."}
from fastapi import Request
from fastapi.responses import JSONResponse
import traceback

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "traceback": traceback.format_exc()}
    )
