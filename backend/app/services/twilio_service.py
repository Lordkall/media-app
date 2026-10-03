import os
import re

TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
TWILIO_WHATSAPP_NUMBER = os.getenv("TWILIO_WHATSAPP_NUMBER", "whatsapp:+17372508034")

def normalize_whatsapp_phone(phone: str) -> str | None:
    """
    Normaliza el número para WhatsApp asegurando el código de país.
    Especial para Venezuela: +58 424... / 0424... -> +58424...
    """
    if not phone:
        return None
    cleaned = re.sub(r"[^\d+]", "", phone.strip())
    
    if cleaned.startswith("04"):
        cleaned = "58" + cleaned[1:]
    elif cleaned.startswith("+5804"):
        cleaned = "58" + cleaned[4:]
    elif cleaned.startswith("+584"):
        cleaned = cleaned[1:]
    elif cleaned.startswith("+"):
        cleaned = cleaned[1:]

    if not cleaned.startswith("+"):
        cleaned = "+" + cleaned

    return cleaned

def send_whatsapp_appointment_reminder(to_phone: str, patient_name: str, doctor_name: str, appointment_date_str: str, turn_number: int, appointment_time_str: str = "") -> bool:
    """
    Envía el recordatorio de cita médica por WhatsApp usando Twilio.
    Exclusivo para doctores VIP en la ventana de 23-24 horas antes de la cita.
    """
    if not TWILIO_ACCOUNT_SID or not TWILIO_AUTH_TOKEN:
        print("[TWILIO] Credenciales de Twilio no configuradas en variables de entorno")
        return False

    try:
        from twilio.rest import Client
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        
        normalized_to = normalize_whatsapp_phone(to_phone)
        if not normalized_to:
            print("[TWILIO] Número de teléfono inválido para WhatsApp")
            return False

        to_whatsapp = f"whatsapp:{normalized_to}"
        from_whatsapp = TWILIO_WHATSAPP_NUMBER if TWILIO_WHATSAPP_NUMBER.startswith("whatsapp:") else f"whatsapp:{TWILIO_WHATSAPP_NUMBER}"

        time_part = f" a las {appointment_time_str}" if appointment_time_str else ""
        body = (
            f"¡Hola {patient_name}! 👋 Te recordamos desde *Salud Now* que tu cita médica con {doctor_name} "
            f"es mañana *{appointment_date_str}*{time_part} (Turno #{turn_number}). "
            f"Por favor asiste puntual a tu consulta."
        )

        try:
            message = client.messages.create(
                from_=from_whatsapp,
                body=body,
                to=to_whatsapp
            )
            print(f"[TWILIO] WhatsApp enviado con éxito a {normalized_to}. SID: {message.sid}")
            return True
        except Exception as api_err:
            print(f"[TWILIO ERROR al enviar mensaje]: {api_err}")
            return False

    except Exception as e:
        print(f"[TWILIO ERROR] No se pudo inicializar Twilio: {e}")
        return False
