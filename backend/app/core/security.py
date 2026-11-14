import os
import logging
import bcrypt
from datetime import datetime, timedelta, timezone
from typing import Optional
from jose import jwt

logger = logging.getLogger("uvicorn.error")

ENVIRONMENT = os.getenv("ENVIRONMENT", "development").lower()
DEFAULT_INSECURE_SECRET = "a-very-secret-key-change-in-production"
SECRET_KEY = os.getenv("SECRET_KEY", DEFAULT_INSECURE_SECRET)

if ENVIRONMENT in ("production", "prod"):
    if not SECRET_KEY or SECRET_KEY == DEFAULT_INSECURE_SECRET:
        raise RuntimeError(
            "CRITICAL SECURITY CONFIGURATION: A strong, unique SECRET_KEY environment variable "
            "must be provided in production environments!"
        )
else:
    if SECRET_KEY == DEFAULT_INSECURE_SECRET:
        logger.warning(
            "[SECURITY WARNING] Running with default development SECRET_KEY. "
            "Set a secure SECRET_KEY in production."
        )

ALGORITHM = os.getenv("ALGORITHM", "HS256")
if ALGORITHM not in ("HS256", "HS384", "HS512"):
    ALGORITHM = "HS256"

ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", str(60 * 24 * 7)))

def verify_password(plain_password: str, hashed_password: str) -> bool:
    if not hashed_password or not plain_password:
        return False
    # Validar formato bcrypt seguro ($2a$, $2b$, $2y$) y evitar comparaciones en texto plano
    if not (hashed_password.startswith("$2b$") or hashed_password.startswith("$2a$") or hashed_password.startswith("$2y$")):
        logger.warning("[SECURITY] Rechazado intento de autenticación con hash de contraseña inválido o no seguro.")
        return False
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False

def get_password_hash(password: str) -> str:
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt
