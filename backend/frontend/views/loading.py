import asyncio
import flet as ft
from core import colors

def LoadingView(page: ft.Page, user):
    async def view_loaded():
        await asyncio.sleep(3.5)
        
        # Navigate to home
        from views.home import HomeView
        
        page.views.clear()
        page.nav_push(HomeView(page, user))
        page.update()
        
    page.run_task(view_loaded)

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
                gradient=ft.LinearGradient(
                    begin=ft.alignment.top_left,
                    end=ft.alignment.bottom_right,
                    colors=["#E0EAFC", "#CFDEF3", "#B3C6DF"]
                )
            )
        ],
        vertical_alignment=ft.MainAxisAlignment.CENTER,
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        bgcolor=ft.colors.TRANSPARENT
    )
    
    return view
