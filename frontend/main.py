import flet as ft
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from views.login import LoginView

async def main(page: ft.Page):
    page.title = "Salud Now"
    page.theme_mode = ft.ThemeMode.LIGHT
    page.fonts = {
        "Inter": "https://raw.githubusercontent.com/rsms/inter/master/docs/font-files/Inter-Regular.woff2"
    }
    page.theme = ft.Theme(font_family="Inter")
    page.window.min_width = 360
    page.window.min_height = 600
    
    async def view_pop(e):
        if len(page.views) > 1:
            page.views.pop()
            # If returning to home, refresh it
            if len(page.views) == 1:
                try:
                    uid = await page.shared_preferences.get("user_id")
                    if uid:
                        page.pubsub.send_all_on_topic(f"user_{uid}", "refresh_home")
                except: pass
            page.update()
        else:
            snack = ft.SnackBar(ft.Text("Presiona 'Cerrar sesión' si deseas salir."), duration=3000)
            page.overlay.append(snack)
            snack.open = True
            page.update()
            
    page.on_view_pop = view_pop
    
    # Auto-login if session token exists
    session_token = None
    user_id = None
    try:
        session_token = await page.shared_preferences.get("session_token")
        user_id = await page.shared_preferences.get("user_id")
    except Exception as e:
        print("Error getting shared_preferences:", e)
    
    if session_token and user_id:
        from app.models.users import User
        from sqlalchemy import create_engine, select
        from sqlalchemy.orm import sessionmaker
        
        try:
            from core.config import SYNC_DB_URL
            sync_engine = create_engine(SYNC_DB_URL, pool_pre_ping=True)
            SyncSession = sessionmaker(bind=sync_engine)
            with SyncSession() as session:
                user = session.execute(select(User).where(User.id == user_id)).scalars().first()
                if user and user.session_token == session_token:
                    from views.home import HomeView
                    page.views.clear()
                    page.views.append(HomeView(page, user))
                    page.update()
                    return
        except Exception as e:
            pass # Si falla, caer al login normal

    page.views.clear()
    page.views.append(LoginView(page))
    page.update()

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

if __name__ == "__main__":
    try:
        ft.app(target=main, view=ft.AppView.WEB_BROWSER, host="0.0.0.0", port=8550, assets_dir="assets")
    except AttributeError:
        # En Android/iOS via serious_python a veces 'flet' no exporta 'app'
        # El contenedor nativo ya invoca 'main' automáticamente.
        pass
