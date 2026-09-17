import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import logging

SMTP_SERVER = os.getenv("SMTP_SERVER")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")

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
            <p>Hemos recibido una solicitud para restablecer la contraseña de tu cuenta en <strong>MedIA</strong>. Si fuiste tú, puedes configurar una nueva contraseña haciendo clic en el botón de abajo:</p>
            
            <div class="btn-container">
                <a href="{{ reset_url }}" class="btn" style="color: #ffffff;">Restablecer Contraseña</a>
            </div>
            
            <p class="warning">Este enlace <strong>expirará en 15 minutos</strong> por razones de seguridad.</p>
            <p>Si no solicitaste un cambio de contraseña, puedes ignorar este correo de forma segura. Tu cuenta sigue protegida.</p>
            
            <p>Saludos,<br>El equipo de MedIA</p>
        </div>
        <div class="footer">
            <p>&copy; 2026 MedIA. Todos los derechos reservados.</p>
            <p>Si el botón no funciona, copia y pega el siguiente enlace en tu navegador:<br>
            <a href="{{ reset_url }}" style="color: #0056b3; word-break: break-all;">{{ reset_url }}</a></p>
        </div>
    </div>
</body>
</html>
"""

def send_reset_email(to_email: str, reset_url: str):
    """
    Envía el correo HTML con el enlace de recuperación.
    Si no hay credenciales SMTP configuradas, imprime el enlace en consola (útil para desarrollo).
    """
    html_content = html_template.replace("{{ reset_url }}", reset_url)
    
    if not SMTP_SERVER or not SMTP_USER:
        print(f"\n--- [MOCK EMAIL] ---")
        print(f"To: {to_email}")
        print(f"Subject: Recuperación de Contraseña - MedIA")
        print(f"Reset Link: {reset_url}")
        print(f"--------------------\n")
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Recuperación de Contraseña - MedIA"
    msg["From"] = f"MedIA Soporte <{SMTP_USER}>"
    msg["To"] = to_email
    
    msg.attach(MIMEText(html_content, "html"))
    
    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        if SMTP_PASSWORD:
            server.login(SMTP_USER, SMTP_PASSWORD)
        server.sendmail(SMTP_USER, to_email, msg.as_string())
        server.quit()
    except Exception as e:
        logger.error(f"Error enviando correo a {to_email}: {e}")
        print(f"Error enviando correo a {to_email}: {e}")
