import flet as ft
from core import colors
import sys
import os

base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.append(base_path)
sys.path.append(os.path.join(base_path, 'backend'))
from app.models.users import User
from sqlalchemy import select
from views.register import RegisterView
from views.password_recovery import PasswordRecoveryView

def LoginView(page: ft.Page):
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
            import asyncio
            auth_data = await asyncio.to_thread(client.login, email, password)
            
            # 2. Guardar sesión
            try:
                # El token viene en auth_data["access_token"]
                page.client_storage.set("session_token", auth_data["access_token"])
                
                import jwt
                decoded = jwt.decode(auth_data["access_token"], options={"verify_signature": False})
                user_id = decoded.get("id")
                page.client_storage.set("user_id", str(user_id))
            except Exception as e:
                print("Error setting client_storage:", e)
                
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
            import asyncio
            me_data = await asyncio.to_thread(client.get, "/users/me")
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

            fcm_token = os.environ.get("FCM_TOKEN")
            if fcm_token:
                await asyncio.to_thread(client.put, "/users/me", {"fcm_token": fcm_token})

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

    email_input.on_submit = handle_login
    password_input.on_submit = handle_login



    content = ft.Container(
        content=ft.Column(
            [
                ft.Container(height=10),
                ft.Image(
                    src="logo.png",
                    width=140,
                    height=140,
                    fit=ft.ImageFit.CONTAIN,
                ),
                ft.Text("Inicie sesión", size=22, weight=ft.FontWeight.W_800, color=colors.PRIMARY),
                ft.Text("Ingrese a su cuenta de Salud Now", size=13, color=colors.TEXT_LIGHT, text_align=ft.TextAlign.CENTER),
                ft.Container(height=15),
                email_input,
                ft.Container(height=5),
                password_input,
                error_text,
                ft.Container(
                    content=ft.Button(
                        "Ingresar",
                        style=ft.ButtonStyle(bgcolor=colors.PRIMARY, color="white"),
                        on_click=handle_login,
                    ),
                    width=200,
                    height=45
                ),

                # Footer con links
                ft.Container(
                    content=ft.Column(
                        [
                            ft.Row([
                                ft.Text("¿Aún no te has registrado?", color=colors.TEXT_LIGHT, size=12),
                                ft.TextButton("Crear cuenta", on_click=lambda _: page.views.append(RegisterView(page)) or page.update() if not (page.views and getattr(page.views[-1], "route", None) == "/register") else None)
                            ], alignment=ft.MainAxisAlignment.CENTER),
                            ft.Row([
                                ft.Text("¿Olvidaste tu contraseña?", color=colors.TEXT_LIGHT, size=12),
                                ft.TextButton("Recupérala aquí", on_click=lambda _: page.views.append(PasswordRecoveryView(page)) or page.update() if not (page.views and getattr(page.views[-1], "route", None) == "/password-recovery") else None)
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
        ),
        width=400
    )

    return ft.View(
        route="/login",
        controls=[
            ft.Container(
                content=content,
                padding=20,
                expand=True,
                alignment=ft.alignment.center
            )
        ],
        bgcolor=colors.BACKGROUND
    )
