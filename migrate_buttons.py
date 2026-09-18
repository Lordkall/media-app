import os

VIEWS_DIR = os.path.join("frontend", "views")

def migrate_buttons():
    for root, dirs, files in os.walk(VIEWS_DIR):
        for file in files:
            if not file.endswith(".py"):
                continue
            filepath = os.path.join(root, file)
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()

            new_content = content.replace("ft.ElevatedButton", "ft.Button")

            if new_content != content:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(new_content)
                print(f"Migrated {filepath}")

if __name__ == "__main__":
    migrate_buttons()
