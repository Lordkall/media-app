with open('backend/frontend/main.py', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''if hasattr(ft, "app"):
        ft.app(target=main, assets_dir="assets")'''
replacement = '''if hasattr(ft, "run"):
        ft.run(main)
    elif hasattr(ft, "app"):
        ft.app(target=main, assets_dir="assets")'''

if target in content:
    content = content.replace(target, replacement)
    with open('backend/frontend/main.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced")
else:
    print("Target not found")
