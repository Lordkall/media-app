import re
from pydantic import BaseModel, EmailStr, field_validator

class PasswordResetRequest(BaseModel):
    email: EmailStr

class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, password: str) -> str:
        if (
            len(password) < 6
            or not re.search(r"[A-Z]", password)
            or not re.search(r"[a-zA-Z]", password)
            or not re.search(r"[0-9]", password)
        ):
            raise ValueError(
                "La nueva contraseña debe tener al menos 6 caracteres, incluir números, letras y una letra mayúscula"
            )
        return password

