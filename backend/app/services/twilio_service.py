import os
import re
import json
from dotenv import load_dotenv

# Cargar variables de entorno si existen en el archivo .env
load_dotenv()

def normalize_whatsapp_phone(phone: str) -> str | None:
    """
    Normaliza el número para WhatsApp asegurando el código de país.
    El sistema asume que todos los números inician con +58 (Venezuela).
    Ejemplos:
      - 04247618159       -> +584247618159
      - 4247618159        -> +584247618159
      - +58 424 761 8159  -> +584247618159
      - 0412-1234567      -> +584121234567
      - 0212 9876543      -> +582129876543
      - 5804247618159     -> +584247618159
      - 584247618159      -> +584247618159
    """
    if not phone:
        return None
    cleaned = re.sub(r"\D", "", str(phone).strip())
    if not cleaned:
        return None

    # Si empieza con el código 58, quitamos el 58 temporalmente para normalizar el número base
    if cleaned.startswith("58"):
        base = cleaned[2:]
    else:
        base = cleaned

    # Quitar cualquier 0 inicial (ej: 0424 -> 424, 0212 -> 212)
    base = base.lstrip("0")

    # En Venezuela un número telefónico completo tiene al menos 7 dígitos (fijo local) o 10 dígitos (móvil)
    if len(base) < 7:
        return None

    return f"+58{base}"

def send_whatsapp_appointment_reminder(
    to_phone: str,
    patient_name: str,
    doctor_name: str,
    appointment_date_str: str,
    turn_number: int,
    appointment_time_str: str = ""
) -> bool:
    """
    Envía el recordatorio de cita médica por WhatsApp usando Twilio.
    Normaliza el número para Venezuela (+58) y maneja tanto templates aprobados
    como mensajes directos.
    """
    account_sid = os.getenv("TWILIO_ACCOUNT_SID")
    auth_token = os.getenv("TWILIO_AUTH_TOKEN")
    from_raw = os.getenv("TWILIO_WHATSAPP_NUMBER", "whatsapp:+17372508034")
    content_sid = os.getenv("TWILIO_CONTENT_SID", "HXfe5ab5f00277942d4d4200328b4d403c")

    if not account_sid or not auth_token:
        print("[TWILIO] Error: TWILIO_ACCOUNT_SID o TWILIO_AUTH_TOKEN no configurados en variables de entorno")
        return False

    normalized_to = normalize_whatsapp_phone(to_phone)
    if not normalized_to:
        print(f"[TWILIO] Número de teléfono inválido para WhatsApp: {to_phone}")
        return False

    to_whatsapp = f"whatsapp:{normalized_to}"
    from_whatsapp = from_raw if from_raw.startswith("whatsapp:") else f"whatsapp:{from_raw}"

    time_part = f" a las {appointment_time_str}" if appointment_time_str else ""
    body = (
        f"¡Hola {patient_name}! 👋 Te recordamos desde *Salud Now* que tu cita médica con {doctor_name} "
        f"es mañana *{appointment_date_str}*{time_part} (Turno #{turn_number}). "
        f"Por favor asiste puntual a tu consulta."
    )

    try:
        from twilio.rest import Client
        client = Client(account_sid, auth_token)

        # 1. Enviar con ContentSid (plantilla aprobada para WhatsApp Sandbox / Meta)
        if content_sid:
            try:
                # La plantilla pre-aprobada de Sandbox espera:
                # {{1}} = Fecha / Día
                # {{2}} = Hora
                # {{3}} = Letra / Opción de Confirmación
                # {{4}} = Letra / Opción de Reprogramación
                variables = {
                    "1": appointment_date_str,
                    "2": appointment_time_str or "08:00 AM",
                    "3": "C",
                    "4": "R",
                }
                message = client.messages.create(
                    from_=from_whatsapp,
                    to=to_whatsapp,
                    content_sid=content_sid,
                    content_variables=json.dumps(variables)
                )
                print(f"[TWILIO] WhatsApp enviado con éxito con ContentSid a {normalized_to}. SID: {message.sid}")
                return True
            except Exception as template_err:
                print(f"[TWILIO] Falló envío con template ({template_err}), intentando envío de texto directo...")

        # 2. Enviar con cuerpo directo
        message = client.messages.create(
            from_=from_whatsapp,
            body=body,
            to=to_whatsapp
        )
        print(f"[TWILIO] WhatsApp enviado con éxito a {normalized_to}. SID: {message.sid}")
        return True

    except Exception as api_err:
        err_msg = str(api_err)
        print(f"[TWILIO ERROR al enviar WhatsApp a {to_whatsapp}]: {err_msg}")
        if "63016" in err_msg:
            print(f"[TWILIO AVISO Sandbox] El número {normalized_to} no ha iniciado sesión en el Sandbox de Twilio en las últimas 24 horas (enviar mensaje de unión al número sandbox).")
        return False
