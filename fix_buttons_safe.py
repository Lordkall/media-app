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
            
            # Use non-greedy match for everything inside the parentheses.
            # Only match up to the first closing parenthesis of the button? No, that's hard.
            # Let's just find and replace specific lines:
            
            lines = content.split('\n')
            for i, line in enumerate(lines):
                # We only process if it's not a complex multiline that breaks easily.
                # Actually, many buttons are simple. 
                pass

            # A much safer regex that only applies if there are no inner parentheses between the start and the attributes.
            # This is hard.
            
            def safe_replace(match):
                # match.group(0) is the full match
                text = match.group(0)
                # If there's an opening or closing paren in the middle, it might be nested, skip it or handle carefully.
                pass

            # Let's just use re.sub but strictly within the SAME LINE to avoid catastrophic multiline matching.
            
            def replace_on_line(line):
                # 1. color="...", bgcolor=...
                line = re.sub(r"(ft\.(?:ElevatedButton|TextButton|OutlinedButton|IconButton)\([^)]*?)color=([^,)]+)([^)]*?)bgcolor=([^,)]+)(.*?\))", 
                              r"\1style=ft.ButtonStyle(color=\2, bgcolor=\4)\5", line)
                
                # 2. bgcolor=..., color=...
                line = re.sub(r"(ft\.(?:ElevatedButton|TextButton|OutlinedButton|IconButton)\([^)]*?)bgcolor=([^,)]+)([^)]*?)color=([^,)]+)(.*?\))", 
                              r"\1style=ft.ButtonStyle(bgcolor=\2, color=\4)\5", line)

                # 3. bgcolor=... only
                line = re.sub(r"(ft\.(?:ElevatedButton|TextButton|OutlinedButton|IconButton)\([^)]*?)bgcolor=([^,)]+)(.*?\))", 
                              r"\1style=ft.ButtonStyle(bgcolor=\2)\3", line)
                
                return line

            new_lines = []
            for line in lines:
                new_line = replace_on_line(line)
                new_lines.append(new_line)
            
            new_content = '\n'.join(new_lines)
            
            if new_content != original_content:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(new_content)
                print(f"Updated {filepath}")

if __name__ == "__main__":
    update_buttons()
