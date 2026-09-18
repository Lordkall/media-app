# frontend/core/config.py

# URL base para la API REST del backend.
# Cambiar por la URL pública cuando se despliegue# API_BASE_URL = "http://127.0.0.1:8000/api/v1"
API_BASE_URL = "https://media-app-production-7a1f.up.railway.app/api/v1"

# URL de conexión directa a la base de datos para vistas que lo requieran.
# Nota: Se usa pg8000 para compatibilidad con Android.
# Cambiar por la URL de la base de datos externa (ej. "postgresql+pg8000://user:pass@host/db")
SYNC_DB_URL = "postgresql+pg8000://postgres:nPWDQARrlHWjEGyACJJxfdTEGSKKEkRr@altaria.proxy.rlwy.net:21931/railway"

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Motor global para Flet para evitar fugas de conexiones y congelamientos
global_sync_engine = create_engine(SYNC_DB_URL, pool_size=20, max_overflow=30, pool_pre_ping=True)
GlobalSession = sessionmaker(bind=global_sync_engine)
