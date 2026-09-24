import os
import glob
import re

views_dir = r"c:\Users\Victoria Carmona\Desktop\MedIA\backend\frontend\views"
files_to_fix = glob.glob(os.path.join(views_dir, "*.py"))

for filepath in files_to_fix:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # Remove `import sys` ONLY IF IT IS on its own line (and not part of another import)
    # Actually, let's just remove the specific block:
    
    # 1. Remove base_path = ...
    content = re.sub(r'^[ \t]*base_path\s*=\s*os\.path\.abspath[^\n]+\n', '', content, flags=re.MULTILINE)
    
    # 2. Remove `if base_path not in sys.path:` lines that might be empty or followed by whitespace
    # We will just remove the if statement itself. If the next line was a from import, we should keep it.
    # But wait, home.py line 196 is:
    # "        if base_path not in sys.path:         from app.models.notifications import Notification"
    # Wait, if it's on the same line, let's replace `if base_path not in sys.path:         from` with `        from`
    content = re.sub(r'^[ \t]*if base_path not in sys\.path:[ \t]*\n?', '', content, flags=re.MULTILINE)
    content = re.sub(r'^[ \t]*if base_path not in sys\.path:[ \t]+(?=from |import )', '', content, flags=re.MULTILINE)
    
    if original != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed broken sys.path blocks in {os.path.basename(filepath)}")
