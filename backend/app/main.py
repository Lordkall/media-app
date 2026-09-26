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
            await conn.execute(text("ALTER TABLE users ALTER COLUMN avatar_url TYPE TEXT;"))
            await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR;"))
    except Exception as e:
        print(f"Migration error (might already be TEXT): {e}")
        
    # Start BCV background updater
    bcv_task = asyncio.create_task(bcv_updater_loop())
    
    yield
    
    # Cleanup on shutdown
    bcv_task.cancel()

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
