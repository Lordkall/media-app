import flet as ft
import flet_local_auth as auth

def main(page: ft.Page):
    local_auth = auth.LocalAuthentication()
    
    async def check():
        try:
            res = await local_auth.can_check_biometrics()
            print("Can check biometrics:", res)
        except Exception as e:
            print("Error:", e)
        page.window.close()
        
    page.run_task(check)
    page.update()

ft.run(main)
