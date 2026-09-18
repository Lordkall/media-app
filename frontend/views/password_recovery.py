import flet as ft
from core import colors
import requests

def PasswordRecoveryView(page: ft.Page):
    email_input = ft.TextField(
        label="Correo Electrónico",
        bgcolor=colors.INPUT_BG,
        color=colors.TEXT_DARK
    )
    
    error_text = ft.Text(value="", color="red", size=12)
    success_text = ft.Text(value="", color="green", size=12)
    
    def handle_request(e):
        error_text.value = ""
        success_text.value = ""
        page.update()
        
        email = email_input.value.strip()
        if not email:
            error_text.value = "Por favor ingresa tu correo electrónico."
            page.update()
            return
            
        try:
            from core.api_client import client
            client.post("/password-reset/request", json={"email": email})
            success_text.value = "Enlace enviado. Revisa tu correo (o la consola)."
            email_input.value = ""
        except Exception as ex:
            if hasattr(ex, "response") and ex.response is not None:
                try:
                    error_data = ex.response.json()
                    error_text.value = error_data.get("detail", "Error al procesar la solicitud.")
                except:
                    error_text.value = f"Error del servidor: {ex.response.status_code}"
            else:
                error_text.value = f"Error: {ex}"
            
        page.update()
        
    def handle_confirm(e):
        error_text.value = ""
        success_text.value = ""
        page.update()
        
        # We need to find the textfields since they were added to the view
        token_field = None
        new_password_field = None
        for ctrl in page.views[-1].controls[2].controls:
            if getattr(ctrl, "key", None) == "token_input":
                token_field = ctrl
            elif getattr(ctrl, "key", None) == "new_password_input":
                new_password_field = ctrl
                
        token = token_field.value.strip() if token_field else ""
        new_pwd = new_password_field.value if new_password_field else ""
        
        if not token or not new_pwd:
            error_text.value = "Ingresa el token y la nueva contraseña."
            page.update()
            return
            
        try:
            from core.api_client import client
            client.post("/password-reset/confirm", json={"token": token, "new_password": new_pwd})
            success_text.value = "Contraseña actualizada exitosamente. Puedes volver a iniciar sesión."
            token_field.value = ""
            new_password_field.value = ""
        except Exception as ex:
            if hasattr(ex, "response") and ex.response is not None:
                try:
                    error_data = ex.response.json()
                    error_text.value = error_data.get("detail", "Error al procesar la solicitud.")
                except:
                    error_text.value = f"Error del servidor: {ex.response.status_code}"
            else:
                error_text.value = f"Error: {ex}"
            
        page.update()
        
    return ft.View(
        route="/password_recovery",
        bgcolor=colors.BACKGROUND,
        controls=[
            ft.Row([
                ft.IconButton(
                    icon=ft.Icons.ARROW_BACK,
                    icon_color=colors.PRIMARY,
                    on_click=lambda _: [page.views.pop(), page.update()]
                )
            ]),
            ft.Container(expand=True),
            ft.Column(
                [
                    ft.Icon(ft.Icons.LOCK_RESET, size=80, color=colors.PRIMARY),
                    ft.Text("Recuperar Contraseña", size=24, weight=ft.FontWeight.BOLD, color=colors.PRIMARY),
                    ft.Text("Ingresa tu correo para recibir un enlace de recuperación.", text_align=ft.TextAlign.CENTER, color=colors.TEXT_LIGHT),
                    ft.Container(height=20),
                    email_input,
                    error_text,
                    success_text,
                    ft.Container(height=10),
                    ft.ElevatedButton(
                        "Enviar Enlace",
                        bgstyle=ft.ButtonStyle(color=colors.PRIMARY, style=ft.ButtonStyle(bgcolor=colors.INPUT_BG, color=colors.TEXT_DARK),
                        key="token_input"
                    ),
                    ft.TextField(
                        label="Nueva Contraseña",
                        password=True,
                        can_reveal_password=True,
                        bgcolor=colors.INPUT_BG,
                        color=colors.TEXT_DARK,
                        key="new_password_input"
                    ),
                    ft.ElevatedButton(
                        "Restablecer",
                        style=ft.ButtonStyle(bgcolor=colors.PRIMARY, color="white"),
                        width=200,
                        on_click=lambda e: handle_confirm(e)
                    )
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.CENTER,
                width=300
            ),
            ft.Container(expand=True)
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
    )
