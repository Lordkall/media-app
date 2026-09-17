from fastapi import FastAPI
from app.api.v1.router import api_router

app = FastAPI(title="MedIA Backend", version="1.0.0")

app.include_router(api_router, prefix="/api/v1")

@app.get("/")
def read_root():
    return {"message": "Welcome to MedIA API"}
