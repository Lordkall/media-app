# frontend/core/config.py

# URL base para la API REST del backend.
# Cambiar por la URL pública cuando se despliegue (ej. "https://mi-backend.render.com/api/v1")
API_BASE_URL = "https://media-backend-mvqw.onrender.com/api/v1"

# URL de conexión directa a la base de datos para vistas que lo requieran.
# Nota: Se usa pg8000 para compatibilidad con Android.
# Cambiar por la URL de la base de datos externa (ej. "postgresql+pg8000://user:pass@host/db")
SYNC_DB_URL = "postgresql+pg8000://postgres:12345@127.0.0.1:5432/postgres"
