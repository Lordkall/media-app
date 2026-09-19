import flet as ft
import flet_lottie as fl
from core import colors
import threading

def LoadingView(page: ft.Page, user):
    def navigate_home():
        # Navigate to home
        from views.home import HomeView
        page.views.clear()
        page.views.append(HomeView(page, user))
        page.update()

    content = ft.Column(
        [
            ft.Text("Cargando...", size=24, weight=ft.FontWeight.BOLD, color=colors.PRIMARY),
            fl.Lottie(
                src="catmed.json",
                repeat=True,
                reverse=False,
                animate=True,
                width=300,
                height=300,
                fit="contain"
            ),
        ],
        alignment=ft.MainAxisAlignment.CENTER,
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        expand=True
    )

    view = ft.View(
        route="/loading",
        controls=[content],
        vertical_alignment=ft.MainAxisAlignment.CENTER,
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        bgcolor=colors.BACKGROUND
    )
    
    # We trigger the timeout when the view is created
    timer = threading.Timer(3.5, navigate_home)
    timer.start()
    
    return view
