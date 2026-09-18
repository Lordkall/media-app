from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.router import api_router

app = FastAPI(title="MedIA Backend", version="1.0.0")

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

app.mount("/", flet_fastapi.app(
    flet_main, 
    assets_dir=os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend", "assets"))
))
from fastapi import Request
from fastapi.responses import JSONResponse
import traceback

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "traceback": traceback.format_exc()}
    )
