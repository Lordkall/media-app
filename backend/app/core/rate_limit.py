import time
import logging
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
    # Handle reverse proxies (e.g., Railway / Cloudflare / Nginx)
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"

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

def rate_limit_register(request: Request):
    ip = get_client_ip(request)
    if not limiter.is_allowed(ip, "register", max_requests=10, window_seconds=300):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Demasiadas solicitudes de registro desde esta conexión. Espera unos minutos.",
        )
