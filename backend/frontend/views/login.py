import flet as ft
from core import colors
import sys
import os

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



    login_btn = ft.Button(
        "Ingresar",
        style=ft.ButtonStyle(bgcolor=colors.PRIMARY, color="white"),
    )
    # The handler will be attached after it's defined


    async def handle_login(e):
        error_text.value = ""
        login_btn.disabled = True
        login_btn.text = "Ingresando..."
        page.update()
        
        email = (email_input.value or "").strip().lower()
        password = password_input.value or ""
        
        if not email or not password:
            error_text.value = "Por favor ingrese correo y contraseña."
            login_btn.disabled = False
            login_btn.text = "Ingresar"
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
                await page.client_storage.set_async("session_token", auth_data["access_token"])
                
                import jwt
                decoded = jwt.decode(auth_data["access_token"], options={"verify_signature": False})
                user_id = decoded.get("id")
                await page.client_storage.set_async("user_id", str(user_id))
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
            import requests
            from core.config import API_BASE_URL
            
            def fetch_me():
                resp = requests.get(f"{API_BASE_URL}/users/me", headers={"Authorization": f"Bearer {auth_data['access_token']}"})
                resp.raise_for_status()
                return resp.json()
                
            me_data = await asyncio.to_thread(fetch_me)
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
            user.linked_doctor_id = me_data.get("linked_doctor_id")

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
        finally:
            login_btn.disabled = False
            login_btn.text = "Ingresar"
            page.update()

    login_btn.on_click = handle_login
    email_input.on_submit = handle_login
    password_input.on_submit = handle_login

    def open_register(e):
        if page.views and getattr(page.views[-1], "route", None) == "/register":
            return
        try:
            from views.register import RegisterView as _RegisterView
            view = _RegisterView(page)
            page.views.append(view)
            page.update()
        except Exception as ex:
            snack = ft.SnackBar(ft.Text(f"Error abriendo registro: {ex}"), bgcolor="red")
            page.overlay.append(snack)
            snack.open = True
            page.update()

    def open_recovery(e):
        if page.views and getattr(page.views[-1], "route", None) == "/password-recovery":
            return
        try:
            from views.password_recovery import PasswordRecoveryView as _RecoveryView
            view = _RecoveryView(page)
            page.views.append(view)
            page.update()
        except Exception as ex:
            snack = ft.SnackBar(ft.Text(f"Error abriendo recuperación: {ex}"), bgcolor="red")
            page.overlay.append(snack)
            snack.open = True
            page.update()

    content = ft.Container(
        content=ft.Column(
            [
                ft.Image(
                    src="logo.png",
                    width=100,
                    height=100,
                    fit=ft.ImageFit.CONTAIN,
                ),
                ft.Text("Inicie sesión", size=22, weight=ft.FontWeight.W_800, color=colors.PRIMARY),
                ft.Text("Ingrese a su cuenta de Salud Now", size=13, color=colors.TEXT_LIGHT, text_align=ft.TextAlign.CENTER),
                ft.Container(height=10),
                email_input,
                password_input,
                error_text,
                ft.Container(
                    content=login_btn,
                    width=200,
                    height=45
                ),

                # Footer con links
                ft.Container(
                    content=ft.Column(
                        [
                            ft.Row([
                                ft.Text("¿Aún no te has registrado?", color=colors.TEXT_LIGHT, size=12),
                                ft.TextButton("Crear cuenta", on_click=open_register)
                            ], alignment=ft.MainAxisAlignment.CENTER),
                            ft.Row([
                                ft.Text("¿Olvidaste tu contraseña?", color=colors.TEXT_LIGHT, size=12),
                                ft.TextButton("Recupérala aquí", on_click=open_recovery)
                            ], alignment=ft.MainAxisAlignment.CENTER),
                        ],
                        alignment=ft.MainAxisAlignment.CENTER,
                        spacing=0
                    ),
                    bgcolor=colors.INPUT_BG,
                    padding=10,
                ),
                
                # Botón de descarga de APP (Solo visible en la Web)
                ft.Container(
                    content=ft.ElevatedButton(
                        "Descargar App (Android)",
                        icon=ft.icons.ANDROID,
                        color="white",
                        bgcolor="#3DDC84", # Color oficial de Android
                        on_click=lambda e: page.launch_url("https://github.com/Lordkall/media-app/releases/latest/download/app-release.apk")
                    ),
                    margin=ft.margin.only(top=15),
                    visible=page.web
                )
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            expand=True,
            scroll=ft.ScrollMode.HIDDEN
        ),
        width=400
    )

    return ft.View(
        route="/login",
        controls=[
            ft.Container(
                content=ft.Container(
                    content=content,
                    padding=20,
                    bgcolor=colors.CARD_BG,
                    border_radius=25,
                    border=ft.border.all(1, colors.GLASS_BORDER),
                    blur=ft.Blur(20, 20, ft.BlurTileMode.MIRROR),
                ),
                padding=20,
                expand=True,
                alignment=ft.alignment.center,
                gradient=ft.LinearGradient(
                    begin=ft.alignment.top_left,
                    end=ft.alignment.bottom_right,
                    colors=["#E0EAFC", "#CFDEF3", "#B3C6DF"] # Celeste hielo
                )
            )
        ],
        padding=0,
        bgcolor=ft.colors.TRANSPARENT
    )
