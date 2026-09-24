import os

def replace_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Skip files that don't need changes
    if "views.append(" not in content:
        return False

    # Replace usages
    new_content = content.replace("page.nav_push(", "page.nav_push(")
    new_content = new_content.replace("self.ft_page.nav_push(", "self.ft_page.nav_push(")
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")
        return True
    return False

frontend_dir = os.path.dirname(os.path.abspath(__file__))

for root, _, files in os.walk(frontend_dir):
    if "venv" in root or "__pycache__" in root or "build" in root or "dist" in root:
        continue
    for file in files:
        if file.endswith(".py"):
            filepath = os.path.join(root, file)
            replace_in_file(filepath)
