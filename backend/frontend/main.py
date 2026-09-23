import flet as ft
import sys
import os
frontend_dir = os.path.dirname(__file__)
sys.path.append(os.path.abspath(os.path.join(frontend_dir, '..')))
sys.path.append(os.path.abspath(frontend_dir))

# Fallback para mostrar errores fatales en pantalla (Android black screen fix)
error_traceback = None
try:
    # MONKEY PATCH PARA EVITAR FUGAS DE CONEXIONES EN TODAS LAS VISTAS
    import sqlalchemy
    from core.config import global_sync_engine

    def fake_create_engine(*args, **kwargs):
        return global_sync_engine

    sqlalchemy.create_engine = fake_create_engine
    from views.login import LoginView
except Exception as e:
    import traceback
    error_traceback = traceback.format_exc()

def main(page: ft.Page):
    if error_traceback:
        page.add(ft.Text("FATAL ERROR ON STARTUP:", color="red", weight="bold"))
        page.add(ft.Text(error_traceback, color="red", size=10, selectable=True))
        page.update()
        return

    page.title = "Salud Now"
    page.theme_mode = ft.ThemeMode.LIGHT
    page.fonts = {
        "Inter": "https://raw.githubusercontent.com/rsms/inter/master/docs/font-files/Inter-Regular.woff2"
    }
    page.theme = ft.Theme(
        font_family="Inter",
        canvas_color=ft.colors.WHITE,
        popup_menu_theme=ft.PopupMenuTheme(color=ft.colors.WHITE),
        color_scheme=ft.ColorScheme(
            surface=ft.colors.WHITE,
            on_surface=ft.colors.BLACK,
            surface_tint=ft.colors.WHITE
        )
    )
    
    page.locale_configuration = ft.LocaleConfiguration(
        supported_locales=[
            ft.Locale("es", "ES")
        ],
        current_locale=ft.Locale("es", "ES"),
    )
    
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
            # Prevención de spam
            if not getattr(page, "_exit_snack_shown", False):
                page._exit_snack_shown = True
                snack = ft.SnackBar(ft.Text("Presiona 'Cerrar sesión' si deseas salir."), duration=3000)
                page.overlay.append(snack)
                snack.open = True
                page.update()
                
                # Reset the flag after 3 seconds so they can see it again later if needed
                import threading
                def reset_flag():
                    page._exit_snack_shown = False
                threading.Timer(3.0, reset_flag).start()
            
    page.on_view_pop = view_pop

    async def try_auto_login():
        """
        Se ejecuta como tarea asíncrona DESPUÉS de que el browser sincronizó
        su localStorage con page.client_storage.
        """
        import asyncio
        session_token = None
        user_id = None
        try:
            session_token = await page.client_storage.get_async("session_token")
            user_id = await page.client_storage.get_async("user_id")
        except Exception as ex:
            print("[SESSION] Error leyendo client_storage:", ex)

        if session_token and user_id:
            try:
                import requests
                from core.config import API_BASE_URL
                headers = {"Authorization": f"Bearer {session_token}"}
                
                def fetch_me():
                    resp = requests.get(f"{API_BASE_URL}/users/me", headers=headers)
                    resp.raise_for_status()
                    return resp.json()
                
                # Llamada HTTP en un thread separado con peticion directa para evitar fugas de threads
                me_data = await asyncio.to_thread(fetch_me)

                class UserMock:
                    pass
                u = UserMock()
                u.id = me_data.get("id")
                u.email = me_data.get("email")
                u.first_name = me_data.get("first_name")
                u.last_name = me_data.get("last_name")
                u.role = me_data.get("role")
                u.phone = me_data.get("phone")
                u.state = me_data.get("state")
                u.address = me_data.get("address")
                u.gender = me_data.get("gender")
                u.avatar_url = me_data.get("avatar_url")
                u.linked_doctor_id = me_data.get("linked_doctor_id")
                u.fcm_token = me_data.get("fcm_token")

                from views.home import HomeView
                page.views.clear()
                page.views.append(HomeView(page, u))
                page.update()
                return
            except Exception as ex:
                print("[AUTO-LOGIN ERROR]", ex)
                if hasattr(ex, 'response') and ex.response is not None and ex.response.status_code == 401:
                    try:
                        await page.client_storage.remove_async("session_token")
                        await page.client_storage.remove_async("user_id")
                    except: pass

        # Sin sesión válida: ya se muestra login (fue cargado antes)
        page.views.clear()
        page.views.append(LoginView(page))
        page.update()

    # Lanzar auto-login inmediatamente
    page.run_task(try_auto_login)

    # Mostrar login inmediatamente para no dejar la pantalla en blanco
    # on_load lo reemplazará si hay sesión válida
    try:
        page.views.clear()
        page.views.append(LoginView(page))
        page.update()
    except Exception as e:
        import traceback
        page.add(ft.Text("ERROR AL CARGAR LOGIN:", color="red", weight="bold"))
        page.add(ft.Text(traceback.format_exc(), color="red", size=10, selectable=True))
        page.update()

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

if __name__ == "__main__":
    try:
        if hasattr(ft, "run"):
            ft.run(main)
        else:
            ft.app(target=main, assets_dir="assets")
    except AttributeError:
        pass  # On Android, ft.app is missing but flet-embed calls main() automatically
