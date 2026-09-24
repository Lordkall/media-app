import flet as ft
import sys
import os
frontend_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.abspath(os.path.join(frontend_dir, ".."))
if frontend_dir not in sys.path:
    sys.path.insert(0, frontend_dir)
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

# Fallback para mostrar errores fatales en pantalla (Android black screen fix)
error_traceback = None
try:
    # MONKEY PATCH PARA EVITAR FUGAS DE CONEXIONES EN TODAS LAS VISTAS
    import sqlalchemy
    real_create_engine = sqlalchemy.create_engine

    def fake_create_engine(*args, **kwargs):
        import sys
        # Si core.config no ha terminado de cargar, permitimos crear el engine real
        if 'core.config' not in sys.modules or getattr(sys.modules['core.config'], 'global_sync_engine', None) is None:
            return real_create_engine(*args, **kwargs)
        
        from core.config import global_sync_engine
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
    
    # Global navigation lock to prevent double clicks
    import time
    page._last_nav_time = 0
    def global_nav_push(view):
        if not page.views:
            page._last_nav_time = time.time()
            page.views.append(view)
            return
            
        if time.time() - page._last_nav_time < 0.5:
            return
        # Prevent pushing the same route twice sequentially
        if page.views and getattr(page.views[-1], "route", None) == getattr(view, "route", "N/A"):
            return
        page._last_nav_time = time.time()
        page.views.append(view)
        
    page.nav_push = global_nav_push
    
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
                snack = ft.SnackBar(ft.Text("Presiona ATRÁS nuevamente para salir de la app."), duration=3000)
                page.overlay.append(snack)
                snack.open = True
                page.update()
                
                # Reset the flag after 3 seconds so they can see it again later if needed
                import threading
                def reset_flag():
                    page._exit_snack_shown = False
                threading.Timer(3.0, reset_flag).start()
            else:
                # They pressed back again within 3 seconds, exit the app
                page.views.pop()
                page.update()
            
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
                    import time
                    last_ex = None
                    for _ in range(5): # 5 intentos para dar tiempo a la red
                        try:
                            resp = requests.get(f"{API_BASE_URL}/users/me", headers=headers, timeout=5)
                            resp.raise_for_status()
                            return resp.json()
                        except Exception as e:
                            last_ex = e
                            if hasattr(e, 'response') and e.response is not None and e.response.status_code == 401:
                                raise e # Token expirado o inválido, no reintentar
                            time.sleep(1.5)
                    raise last_ex
                
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
                page.nav_push(HomeView(page, u))
                page.update()
                return
            except Exception as ex:
                print("[AUTO-LOGIN ERROR]", ex)
                if hasattr(ex, 'response') and ex.response is not None and ex.response.status_code == 401:
                    try:
                        await page.client_storage.remove_async("session_token")
                        await page.client_storage.remove_async("user_id")
                    except: pass
                else:
                    # Es un error de red o de servidor, no desloguear al usuario
                    page.views.clear()
                    
                    def retry_login(e):
                        page.views.clear()
                        page.nav_push(ft.View(
                            "/loading",
                            controls=[ft.Container(content=ft.ProgressRing(), expand=True, alignment=ft.alignment.center)]
                        ))
                        page.update()
                        page.run_task(try_auto_login)
                        
                    page.nav_push(ft.View(
                        "/error",
                        controls=[
                            ft.Container(
                                content=ft.Column([
                                    ft.Icon(ft.Icons.WIFI_OFF, size=60, color="red"),
                                    ft.Text("Error de conexión al iniciar sesión", size=18, weight=ft.FontWeight.BOLD),
                                    ft.Text("Revisa tu conexión a internet.", text_align=ft.TextAlign.CENTER),
                                    ft.Button("Reintentar", on_click=retry_login, style=ft.ButtonStyle(bgcolor=ft.colors.BLUE, color="white")),
                                    ft.TextButton("Ir al Login Manualmente", on_click=lambda _: [page.views.clear(), page.nav_push(LoginView(page)), page.update()])
                                ], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=20),
                                expand=True,
                                alignment=ft.alignment.center
                            )
                        ]
                    ))
                    page.update()
                    return

        # Sin sesión válida: ya se muestra login (fue cargado antes)
        page.views.clear()
        page.nav_push(LoginView(page))
        page.update()

    # Lanzar auto-login inmediatamente
    page.run_task(try_auto_login)

    # Mostrar login inmediatamente para no dejar la pantalla en blanco
    # on_load lo reemplazará si hay sesión válida
    try:
        page.views.clear()
        page.nav_push(LoginView(page))
        page.update()
    except Exception as e:
        import traceback
        page.add(ft.Text("ERROR AL CARGAR LOGIN:", color="red", weight="bold"))
        page.add(ft.Text(traceback.format_exc(), color="red", size=10, selectable=True))
        page.update()

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

if __name__ == "__main__":
    ft.app(target=main, assets_dir="assets")
