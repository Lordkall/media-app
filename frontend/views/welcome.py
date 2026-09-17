import flet as ft
from frontend.core import colors

def WelcomeView(page: ft.Page):
    
    def go_to_login(e):
        from frontend.views.login import LoginView
        page.views.append(LoginView(page))
        page.update()

    def go_to_register(e):
        from frontend.views.register import RegisterView
        page.views.append(RegisterView(page))
        page.update()



    content = ft.Column(
        [
            ft.Container(height=30),
            ft.Image(
                src="logo.png",
                width=180,
                height=180,
                fit=ft.BoxFit.CONTAIN,
            ),
            ft.Container(height=20),
            ft.Text("Bienvenido", size=26, weight=ft.FontWeight.W_800, color=colors.PRIMARY),
            ft.Container(height=5),
            ft.Text("Agende una cita rápida con su médico especialista", size=14, color=colors.TEXT_LIGHT, text_align=ft.TextAlign.CENTER),
            ft.Container(height=30),
            
            ft.Container(
                content=ft.Column(
                    [
                        ft.ElevatedButton(
                            "Crear una cuenta", 
                            bgcolor=colors.PRIMARY, 
                            color="white",
                            on_click=go_to_register
                        ),

                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                bgcolor=colors.INPUT_BG,
                padding=30,
            ),
            ft.Container(height=20),
            ft.Row(
                [
                    ft.Text("¿Ya tienes una cuenta?", color=colors.TEXT_LIGHT, size=12),
                    ft.TextButton("Iniciar sesión", on_click=go_to_login)
                ],
                alignment=ft.MainAxisAlignment.CENTER
            )
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
    )

    return ft.View(
        route="/",
        controls=[
            ft.Container(
                content=content,
                padding=20,
                expand=True
            )
        ],
        bgcolor=colors.BACKGROUND,
    )
