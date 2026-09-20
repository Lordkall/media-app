import flet as ft
from core import colors

def WelcomeView(page: ft.Page):
    
    def go_to_login(e):
        from views.login import LoginView
        page.views.append(LoginView(page))
        page.update()

    def go_to_register(e):
        from views.register import RegisterView
        page.views.append(RegisterView(page))
        page.update()



    content = ft.Column(
        [
            ft.Container(height=30),
            ft.Image(
                src="logo.png",
                width=180,
                height=180,
                fit=ft.ImageFit.CONTAIN,
            ),
            ft.Container(height=20),
            ft.Text("Bienvenido", size=26, weight=ft.FontWeight.W_800, color=colors.PRIMARY),
            ft.Container(height=5),
            ft.Text("Agende una cita rápida con su médico especialista", size=14, color=colors.TEXT_LIGHT, text_align=ft.TextAlign.CENTER),
            ft.Container(height=30),
            
            ft.Container(
                content=ft.Column(
                    [
                        ft.Button(
                            "Crear una cuenta", 
                            bgcolor=colors.PRIMARY, 
                            color="white",
                            on_click=go_to_register
                        ),

                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                bgcolor=colors.CARD_BG,
                padding=30,
                border_radius=15,
                border=ft.border.all(1, colors.GLASS_BORDER),
                blur=ft.Blur(15, 15, ft.BlurTileMode.MIRROR)
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
        bgcolor=ft.colors.TRANSPARENT,
        controls=[
            ft.Container(
                content=content,
                padding=20,
                expand=True,
                gradient=ft.LinearGradient(
                    begin=ft.alignment.top_left,
                    end=ft.alignment.bottom_right,
                    colors=["#E0EAFC", "#CFDEF3", "#B3C6DF"]
                )
            )
        ]
    )
