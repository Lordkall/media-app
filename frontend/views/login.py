import flet as ft
from core import colors
import sys
import os
import flet_local_auth as auth

base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.append(base_path)
sys.path.append(os.path.join(base_path, 'backend'))
from app.models.users import User
from sqlalchemy import select
from views.register import RegisterView
from views.password_recovery import PasswordRecoveryView

def LoginView(page: ft.Page):
    local_auth = auth.LocalAuthentication()
    if local_auth not in page.overlay:
        page.overlay.append(local_auth)
        
    email_input = ft.TextField(
        label="Correo Electrónico",
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK
    )
    
    password_input = ft.TextField(
        label="Contraseña",
        password=True,
        can_reveal_password=True,
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK
    )

    error_text = ft.Text(value="", color="red", size=12)

    async def handle_fingerprint(e):
        try:
            autorizado = await local_auth.authenticate(
                localized_reason="Inicia sesión con tu huella dactilar"
            )
            if autorizado:
                token = await page.shared_preferences.get("session_token")
                if token:
                    error_text.value = "Huella aceptada. Ingresando..."
                    error_text.color = "green"
                else:
                    error_text.value = "No hay sesión guardada. Inicia sesión con correo primero."
                    error_text.color = "orange"
            else:
                error_text.value = "Autenticación cancelada."
                error_text.color = "red"
        except Exception as ex:
            error_text.value = f"Biometría no disponible o error: {ex}"
            error_text.color = "red"
        page.update()

    async def handle_login(e):
        error_text.value = ""
        page.update()
        
        email = (email_input.value or "").strip()
        password = (password_input.value or "").strip()
        
        if not email or not password:
            error_text.value = "Por favor ingrese correo y contraseña."
            page.update()
            return

        try:
            from core.api_client import client
            
            # 1. Login to get token
            auth_data = client.login(email, password)
            
            # 2. Guardar sesión
            try:
                # El token viene en auth_data["access_token"]
                await page.shared_preferences.set("session_token", auth_data["access_token"])
                
                import jwt
                decoded = jwt.decode(auth_data["access_token"], options={"verify_signature": False})
                user_id = decoded.get("id")
                await page.shared_preferences.set("user_id", str(user_id))
            except Exception as e:
                print("Error setting shared_preferences:", e)
                
            # Desconectar handlers obsoletos de esta pagina
            if hasattr(page, "my_pubsub_topic") and hasattr(page, "my_pubsub_handler"):
                try:
                    page.pubsub.unsubscribe_topic(page.my_pubsub_topic, page.my_pubsub_handler)
                    delattr(page, "my_pubsub_topic")
                    delattr(page, "my_pubsub_handler")
                except: pass
            
            if 'user_id' in locals():
                page.pubsub.send_all_on_topic(f"user_{user_id}", f"force_logout:{getattr(page, 'session_id', '')}")

            # Como HomeView necesita un objeto User por ahora, lo llenamos con los datos del endpoint
            me_data = client.get("/users/me")
            class UserMock:
                pass
            user = UserMock()
            user.id = me_data.get("id")
            user.email = me_data.get("email")
            user.first_name = me_data.get("first_name")
            user.last_name = me_data.get("last_name")
            user.role = me_data.get("role")
            user.phone = me_data.get("phone")
            user.state = me_data.get("state")
            user.address = me_data.get("address")
            user.gender = me_data.get("gender")
            user.avatar_url = me_data.get("avatar_url")

            # Exito: Navegar al Home
            from views.home import HomeView
            home_view = HomeView(page, user)
            page.views.clear()
            page.views.append(home_view)
            page.update()
            
        except Exception as ex:
            if hasattr(ex, "response") and ex.response is not None:
                try:
                    error_data = ex.response.json()
                    error_text.value = error_data.get("detail", "Error de credenciales")
                except:
                    error_text.value = f"Error del servidor: {ex.response.status_code}"
            else:
                error_text.value = f"Error al ingresar: {str(ex)}"
            page.update()



    content = ft.Column(
        [
            ft.Container(height=10),
            ft.Image(
                src="logo.png",
                width=140,
                height=140,
                fit=ft.BoxFit.CONTAIN,
            ),
            ft.Text("Inicie sesión", size=22, weight=ft.FontWeight.W_800, color=colors.PRIMARY),
            ft.Text("Ingrese a su cuenta de Salud Now", size=13, color=colors.TEXT_LIGHT, text_align=ft.TextAlign.CENTER),
            ft.Container(height=15),
            email_input,
            ft.Container(height=5),
            password_input,
            error_text,
            ft.Container(
                content=ft.ElevatedButton(
                    "Ingresar",
                    style=ft.ButtonStyle(bgcolor=colors.PRIMARY, color="white"),
                    on_click=handle_login,
                ),
                width=200,
                height=45
            ),
            ft.Container(
                content=ft.IconButton(
                    icon=ft.Icons.FINGERPRINT,
                    icon_color=colors.PRIMARY,
                    icon_size=50,
                    tooltip="Ingresar con Huella Dactilar",
                    on_click=handle_fingerprint
                ),
                alignment=ft.alignment.Alignment.CENTER
            ),
            ft.Container(expand=True),
            # Footer con links
            ft.Container(
                content=ft.Column(
                    [
                        ft.Row([
                            ft.Text("¿Aún no te has registrado?", color=colors.TEXT_LIGHT, size=12),
                            ft.TextButton("Crear cuenta", on_click=lambda _: [page.views.append(RegisterView(page)), page.update()])
                        ], alignment=ft.MainAxisAlignment.CENTER),
                        ft.Row([
                            ft.Text("¿Olvidaste tu contraseña?", color=colors.TEXT_LIGHT, size=12),
                            ft.TextButton("Recupérala aquí", on_click=lambda _: [page.views.append(PasswordRecoveryView(page)), page.update()])
                        ], alignment=ft.MainAxisAlignment.CENTER),
                    ],
                    alignment=ft.MainAxisAlignment.CENTER,
                    spacing=0
                ),
                bgcolor=colors.INPUT_BG,
                padding=10,
            )
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        expand=True
    )

    return ft.View(
        route="/login",
        controls=[
            ft.Container(
                content=content,
                padding=20,
                expand=True
            )
        ],
        bgcolor=colors.BACKGROUND
    )
