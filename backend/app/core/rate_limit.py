import time
import logging
import ipaddress
import os
from collections import defaultdict
from fastapi import Request, HTTPException, status

logger = logging.getLogger("uvicorn.error")

class InMemoryRateLimiter:
    """Sliding-window in-memory rate limiter with automatic expiration."""
    def __init__(self):
        # Key: (ip, endpoint_bucket) -> list of request timestamps
        self._requests = defaultdict(list)

    def is_allowed(self, client_ip: str, bucket: str, max_requests: int, window_seconds: int) -> bool:
        now = time.time()
        key = (client_ip, bucket)
        timestamps = self._requests[key]

        # Evict timestamps older than window
        cutoff = now - window_seconds
        valid_timestamps = [t for t in timestamps if t > cutoff]
        self._requests[key] = valid_timestamps

        if len(valid_timestamps) >= max_requests:
            logger.warning(
                f"[SECURITY ALERT] Rate limit exceeded for IP {client_ip} on bucket '{bucket}' "
                f"({len(valid_timestamps)}/{max_requests} reqs in {window_seconds}s)"
            )
            return False

        self._requests[key].append(now)
        return True

limiter = InMemoryRateLimiter()

def get_client_ip(request: Request) -> str:
    """Extrae y valida de forma segura la IP real del cliente evitando spoofing."""
    direct_ip = request.client.host if request.client else "unknown"

    # 1. Cloudflare header si está presente
    cf_connecting_ip = request.headers.get("cf-connecting-ip")
    if cf_connecting_ip:
        cleaned = cf_connecting_ip.strip()
        try:
            ipaddress.ip_address(cleaned)
            return cleaned
        except ValueError:
            pass

    # 2. X-Real-IP
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        cleaned = real_ip.strip()
        try:
            ipaddress.ip_address(cleaned)
            return cleaned
        except ValueError:
            pass

    # 3. X-Forwarded-For con validación de formato IP estricta
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        parts = [p.strip() for p in forwarded.split(",") if p.strip()]
        for candidate in parts:
            try:
                ip_obj = ipaddress.ip_address(candidate)
                return str(ip_obj)
            except ValueError:
                continue

    return direct_ip

def rate_limit_login(request: Request):
    ip = get_client_ip(request)
    if not limiter.is_allowed(ip, "login", max_requests=10, window_seconds=60):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Demasiados intentos de inicio de sesión. Por favor espera un minuto.",
        )

def rate_limit_password_reset(request: Request):
    ip = get_client_ip(request)
    if not limiter.is_allowed(ip, "password_reset", max_requests=5, window_seconds=300):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Demasiadas solicitudes de recuperación. Por favor espera unos minutos.",
        )

def rate_limit_password_confirm(request: Request):
    ip = get_client_ip(request)
    if not limiter.is_allowed(ip, "password_confirm", max_requests=5, window_seconds=300):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Demasiados intentos de restablecimiento de contraseña. Por favor espera unos minutos.",
        )

def rate_limit_register(request: Request):
    ip = get_client_ip(request)
    if not limiter.is_allowed(ip, "register", max_requests=10, window_seconds=300):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Demasiadas solicitudes de registro desde esta conexión. Espera unos minutos.",
        )
