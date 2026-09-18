import os
import re

VIEWS_DIR = os.path.join("frontend", "views")

def update_buttons():
    for root, dirs, files in os.walk(VIEWS_DIR):
        for file in files:
            if not file.endswith(".py"):
                continue
            filepath = os.path.join(root, file)
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()

            original_content = content
            
            def replace_color_bgcolor(match):
                prefix = match.group(1)
                color = match.group(2)
                mid = match.group(3)
                bgcolor = match.group(4)
                suffix = match.group(5)
                return f"{prefix}style=ft.ButtonStyle(color={color}, bgcolor={bgcolor}){suffix}"

            def replace_bgcolor_color(match):
                prefix = match.group(1)
                bgcolor = match.group(2)
                mid = match.group(3)
                color = match.group(4)
                suffix = match.group(5)
                return f"{prefix}style=ft.ButtonStyle(bgcolor={bgcolor}, color={color}){suffix}"
                
            def replace_bgcolor_only(match):
                prefix = match.group(1)
                bgcolor = match.group(2)
                suffix = match.group(3)
                if "ButtonStyle" in prefix or "ButtonStyle" in suffix:
                    return match.group(0)
                return f"{prefix}style=ft.ButtonStyle(bgcolor={bgcolor}){suffix}"

            content = re.sub(r"(ft\.(?:ElevatedButton|TextButton|OutlinedButton)\(.*?)color=([^,)]+)(.*?)bgcolor=([^,)]+)(.*?\))", replace_color_bgcolor, content, flags=re.DOTALL)
            content = re.sub(r"(ft\.(?:ElevatedButton|TextButton|OutlinedButton)\(.*?)bgcolor=([^,)]+)(.*?)color=([^,)]+)(.*?\))", replace_bgcolor_color, content, flags=re.DOTALL)
            content = re.sub(r"(ft\.(?:ElevatedButton|TextButton|OutlinedButton)\(.*?)bgcolor=([^,)]+)(.*?\))", replace_bgcolor_only, content, flags=re.DOTALL)
            
            if content != original_content:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Updated {filepath}")

if __name__ == "__main__":
    update_buttons()
