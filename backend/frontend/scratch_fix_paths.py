import os
import glob
import re

frontend_dir = r"c:\Users\Victoria Carmona\Desktop\MedIA\backend\frontend"
files_to_fix = glob.glob(os.path.join(frontend_dir, "**", "*.py"), recursive=True)

for filepath in files_to_fix:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    # Remove     content = re.sub(r'sys\.path\.append\(base_path\)\n?', '', content)
    # Remove     content = re.sub(r'sys\.path\.append\(os\.path\.join\(base_path,\s*[\'"]backend[\'"]\)\)\n?', '', content)
    # Remove if base_path not in sys.path: ...
    content = re.sub(r'if base_path not in sys\.path:\s*sys\.path\.append\(base_path\)\n?', '', content)
    # Remove base_path = ...
    # Be careful not to remove it if it's used for other things, but usually it's only for sys.path
    # content = re.sub(r'base_path\s*=\s*os\.path\.abspath\(os\.path\.join\(os\.path\.dirname\(__file__\),\s*[\'"]\.\.[\'"],\s*[\'"]\.\.[\'"]\)\)\n?', '', content)

    # In main.py specifically:
    if "main.py" in filepath:
        content = re.sub(r'sys\.path\.append\(os\.path\.abspath\(os\.path\.join\(frontend_dir,\s*[\'"]\.\.[\'"]\)\)\)\n?', '', content)
        content = re.sub(r'sys\.path\.append\(os\.path\.abspath\(frontend_dir\)\)\n?', '', content)

    if original != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Cleaned sys.path in {filepath}")

# Restore main.py ft.app exactly at the end
main_path = os.path.join(frontend_dir, "main.py")
with open(main_path, 'r', encoding='utf-8') as f:
    main_content = f.read()

# Replace the whole if __name__ == "__main__": block
target_block = re.search(r'if __name__ == "__main__":.*', main_content, re.DOTALL)
if target_block:
    new_block = """if __name__ == "__main__":
    ft.app(target=main, assets_dir="assets")"""
    main_content = main_content.replace(target_block.group(0), new_block)
    with open(main_path, 'w', encoding='utf-8') as f:
        f.write(main_content)
    print("Restored ft.app in main.py")
