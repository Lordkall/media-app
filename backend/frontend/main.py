import flet as ft
import sys
import os
frontend_dir = os.path.dirname(__file__)
sys.path.append(os.path.abspath(os.path.join(frontend_dir, '..')))
sys.path.append(os.path.abspath(frontend_dir))

# MONKEY PATCH PARA EVITAR FUGAS DE CONEXIONES EN TODAS LAS VISTAS
import sqlalchemy
from core.config import global_sync_engine

def fake_create_engine(*args, **kwargs):
    return global_sync_engine

sqlalchemy.create_engine = fake_create_engine
from views.login import LoginView

def main(page: ft.Page):
    page.title = "Salud Now"
    page.theme_mode = ft.ThemeMode.LIGHT
    page.fonts = {
        "Inter": "https://raw.githubusercontent.com/rsms/inter/master/docs/font-files/Inter-Regular.woff2"
    }
    page.theme = ft.Theme(font_family="Inter")
    page.window.min_width = 360
    page.window.min_height = 600
    
    def view_pop(e):
        # Ignore view_pop events triggered by dialogs/overlays closing
        has_open_dialog = any(
            isinstance(o, (ft.AlertDialog, ft.BottomSheet, ft.DatePicker)) and getattr(o, 'open', False)
            for o in page.overlay
        )
        if has_open_dialog:
            return
        if len(page.views) > 1:
            page.views.pop()
            # If returning to home, refresh it
            if len(page.views) == 1:
                try:
                    uid = page.client_storage.get("user_id")
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
        session_token = page.client_storage.get("session_token")
        user_id = page.client_storage.get("user_id")
    except Exception as e:
        print("Error getting client_storage:", e)
    
    if session_token and user_id:
        from app.models.users import User
        from sqlalchemy import create_engine, select
        from sqlalchemy.orm import sessionmaker
        
        try:
            from core.config import SYNC_DB_URL
            from core.api_client import client
            
            # Restaurar token en el cliente API para futuras llamadas
            client.token = session_token
            
            sync_engine = create_engine(SYNC_DB_URL, pool_pre_ping=True)
            SyncSession = sessionmaker(bind=sync_engine)
            with SyncSession() as session:
                try:
                    user_id_int = int(user_id)
                except ValueError:
                    user_id_int = 0
                user = session.execute(select(User).where(User.id == user_id_int)).scalars().first()
                if user:
                    # Construir UserMock con TODOS los campos necesarios para HomeView
                    class UserMock:
                        pass
                    u = UserMock()
                    u.id = user.id
                    u.email = user.email
                    u.first_name = user.first_name
                    u.last_name = user.last_name
                    u.role = user.role
                    u.phone = getattr(user, 'phone', None)
                    u.state = getattr(user, 'state', None)
                    u.address = getattr(user, 'address', None)
                    u.gender = getattr(user, 'gender', None)
                    u.avatar_url = getattr(user, 'avatar_url', None)
                    u.linked_doctor_id = getattr(user, 'linked_doctor_id', None)
                    u.fcm_token = getattr(user, 'fcm_token', None)

                    fcm_token = os.environ.get("FCM_TOKEN")
                    if fcm_token and user.fcm_token != fcm_token:
                        user.fcm_token = fcm_token
                        session.commit()
                        u.fcm_token = fcm_token

                    from views.home import HomeView
                    page.views.clear()
                    page.views.append(HomeView(page, u))
                    page.update()
                    return
        except Exception as e:
            print("[AUTO-LOGIN ERROR]", e)  # Log para depurar si falla
            pass # Si falla, caer al login normal

    page.views.clear()
    page.views.append(LoginView(page))
    page.update()

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

if __name__ == "__main__":
    ft.run(main)
