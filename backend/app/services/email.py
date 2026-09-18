import os
import logging
import requests

RESEND_API_KEY = os.getenv("RESEND_API_KEY")
SENDER_EMAIL = os.getenv("SENDER_EMAIL", "onboarding@resend.dev")

logger = logging.getLogger(__name__)

html_template = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Recuperación de Contraseña - MedIA</title>
    <style>
        body { font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #f4f7f6; margin: 0; padding: 0; color: #333333; }
        .container { max-width: 600px; margin: 40px auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.05); }
        .header { background-color: #0056b3; padding: 30px 20px; text-align: center; }
        .header img { max-width: 150px; height: auto; }
        .content { padding: 40px 30px; }
        h1 { color: #0056b3; font-size: 24px; margin-top: 0; }
        p { font-size: 16px; line-height: 1.6; color: #555555; margin-bottom: 20px; }
        .btn-container { text-align: center; margin: 35px 0; }
        .btn { background-color: #0056b3; color: #ffffff; text-decoration: none; padding: 14px 30px; border-radius: 6px; font-weight: bold; font-size: 16px; display: inline-block; transition: background-color 0.3s; }
        .btn:hover { background-color: #004494; }
        .footer { background-color: #f8fafc; padding: 20px; text-align: center; font-size: 13px; color: #888888; border-top: 1px solid #eeeeee; }
        .warning { font-size: 14px; color: #888888; }
        @media only screen and (max-width: 600px) { .container { margin: 20px; width: auto; } .content { padding: 30px 20px; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="https://via.placeholder.com/150x50/ffffff/0056b3?text=MedIA+Logo" alt="MedIA Logo">
        </div>
        <div class="content">
            <h1>Restablece tu contraseña</h1>
            <p>Hola,</p>
            <p>Hemos recibido una solicitud para restablecer la contraseña de tu cuenta en <strong>MedIA</strong>. Si fuiste tú, por favor copia el siguiente token de seguridad e ingrésalo en la aplicación:</p>
            
            <div class="btn-container">
                <div style="background-color: #f4f4f4; border: 1px dashed #0056b3; padding: 15px; font-size: 18px; font-weight: bold; letter-spacing: 2px; color: #0056b3;">
                    {{ token }}
                </div>
            </div>
            
            <p class="warning">Este token <strong>expirará en 15 minutos</strong> por razones de seguridad.</p>
            <p>Si no solicitaste un cambio de contraseña, puedes ignorar este correo de forma segura. Tu cuenta sigue protegida.</p>
            
            <p>Saludos,<br>El equipo de MedIA</p>
        </div>
        <div class="footer">
            <p>&copy; 2026 MedIA. Todos los derechos reservados.</p>
            <p>Si prefieres, también puedes hacer clic en el siguiente enlace:<br>
            <a href="{{ reset_url }}" style="color: #0056b3; word-break: break-all;">{{ reset_url }}</a></p>
        </div>
    </div>
</body>
</html>
"""

def send_reset_email(to_email: str, reset_url: str, raw_token: str):
    """
    Envía el correo HTML con el enlace de recuperación usando el API de Resend.
    """
    if not RESEND_API_KEY:
        print(f"\n--- [MOCK EMAIL] ---")
        print(f"To: {to_email}")
        print(f"Token: {raw_token}")
        print(f"--------------------\n")
        raise Exception("Falta configurar la variable RESEND_API_KEY en Railway.")

    html_content = html_template.replace("{{ reset_url }}", reset_url).replace("{{ token }}", raw_token)
    
    headers = {
        "Authorization": f"Bearer {RESEND_API_KEY}",
        "Content-Type": "application/json"
    }
    
    data = {
        "from": f"MedIA Soporte <{SENDER_EMAIL}>",
        "to": [to_email],
        "subject": "Recuperación de Contraseña - MedIA",
        "html": html_content
    }
    
    try:
        response = requests.post("https://api.resend.com/emails", headers=headers, json=data, timeout=10)
        
        if response.status_code >= 400:
            logger.error(f"Error de Resend: {response.text}")
            raise Exception(f"Error enviando correo: {response.text}")
            
    except Exception as e:
        logger.error(f"Fallo al contactar Resend: {e}")
        raise Exception(f"Fallo conectando al servidor de correos: {str(e)}")
