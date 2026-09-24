# frontend/core/config.py

import os

# URL base para la API REST del backend.
# Se lee de la variable de entorno API_URL, o usa la de Railway por defecto
API_BASE_URL = os.getenv("API_URL", "https://media-app-production-dd3f.up.railway.app/api/v1")

# URL de conexión directa a la base de datos para vistas que lo requieran.
# Nota: Se usa pg8000 para compatibilidad con Android.
# Cambiar por la URL de la base de datos externa (ej. "postgresql+pg8000://user:pass@host/db")
SYNC_DB_URL = "postgresql+pg8000://postgres:nPWDQARrlHWjEGyACJJxfdTEGSKKEkRr@altaria.proxy.rlwy.net:21931/railway"

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool

# Motor global para Flet para evitar fugas de conexiones y congelamientos
global_sync_engine = create_engine(SYNC_DB_URL, poolclass=NullPool)
GlobalSession = sessionmaker(bind=global_sync_engine)
