import re

with open('backend/frontend/main.py', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''if __name__ == "__main__":
    if hasattr(ft, "run"):
        ft.run(main)
    elif hasattr(ft, "app"):
        ft.app(target=main, assets_dir="assets")'''

replacement = '''if __name__ == "__main__":
    try:
        if hasattr(ft, "run"):
            ft.run(main)
        else:
            ft.app(target=main, assets_dir="assets")
    except AttributeError:
        import time
        while True:
            time.sleep(1)'''

if target in content:
    content = content.replace(target, replacement)
    with open('backend/frontend/main.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Target not found")
