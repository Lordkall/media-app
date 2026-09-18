import flet as ft
import flet_lottie as fl
from core import colors
import asyncio

def LoadingView(page: ft.Page, user):
    async def view_loaded():
        # Wait 3.5 seconds
        await asyncio.sleep(3.5)
        
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
        controls=[
            ft.Container(
                content=content,
                expand=True,
                alignment=ft.alignment.center
            )
        ],
        bgcolor=colors.BACKGROUND
    )
    
    # We trigger the timeout when the view is created
    page.run_task(view_loaded)
    
    return view
