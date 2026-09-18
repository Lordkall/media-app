import sys
import os
base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'frontend'))
sys.path.append(base_path)

import flet as ft
from views.profile import ProfileView

class MockUser:
    id = 1
    first_name = "Test"
    last_name = "User"
    phone = "123"
    role = "patient"
    avatar_url = ""

def main(page: ft.Page):
    try:
        view = ProfileView(page, MockUser())
        print("ProfileView initialized successfully")
    except Exception as e:
        import traceback
        traceback.print_exc()
    os._exit(1)

ft.run(main)
