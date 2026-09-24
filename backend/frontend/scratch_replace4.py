import re

with open('backend/frontend/main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the while True loop
target_loop = '''    except AttributeError:
        import time
        while True:
            time.sleep(1)'''

replacement_loop = '''    except AttributeError:
        pass  # On Android, ft.app is missing but flet-embed calls main() automatically'''

content = content.replace(target_loop, replacement_loop)

# Add try-catch inside main()
target_main = '''    # Mostrar login inmediatamente para no dejar la pantalla en blanco
    # on_load lo reemplazará si hay sesión válida
    page.views.clear()
    page.nav_push(LoginView(page))
    page.update()'''

replacement_main = '''    # Mostrar login inmediatamente para no dejar la pantalla en blanco
    # on_load lo reemplazará si hay sesión válida
    try:
        page.views.clear()
        page.nav_push(LoginView(page))
        page.update()
    except Exception as e:
        import traceback
        page.add(ft.Text("ERROR AL CARGAR LOGIN:", color="red", weight="bold"))
        page.add(ft.Text(traceback.format_exc(), color="red", size=10, selectable=True))
        page.update()'''

if target_main in content:
    content = content.replace(target_main, replacement_main)
    with open('backend/frontend/main.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Target main not found")
