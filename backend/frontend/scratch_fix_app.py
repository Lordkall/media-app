import re

with open('backend/frontend/main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the whole if __name__ == "__main__": block again
target_block = re.search(r'if __name__ == "__main__":.*', content, re.DOTALL)
if target_block:
    new_block = """if __name__ == "__main__":
    if hasattr(ft, "app"):
        ft.app(target=main, assets_dir="assets")
    else:
        # En Android flet 0.25.0 no existe ft.app, flet-embed llama a main automáticamente
        pass"""
    content = content.replace(target_block.group(0), new_block)
    with open('backend/frontend/main.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Fixed ft.app call in main.py")
