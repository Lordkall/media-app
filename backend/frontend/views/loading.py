import asyncio
import flet as ft
import flet_lottie as fl
from core import colors

def LoadingView(page: ft.Page, user):
    async def view_loaded():
        await asyncio.sleep(3.5)
        
        # Navigate to home
        from views.home import HomeView
        home_view = await asyncio.to_thread(HomeView, page, user)
        
        page.views.clear()
        page.views.append(home_view)
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
        controls=[content],
        vertical_alignment=ft.MainAxisAlignment.CENTER,
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        bgcolor=colors.BACKGROUND
    )
    
    return view
