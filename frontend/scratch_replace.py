import os
import re

def replace_in_files(directory):
    pattern = re.compile(r'^([ \t]*)SYNC_DB_URL\s*=\s*[\'\"].*?[\'\"]', re.MULTILINE)
    replacement = r'\1from frontend.core.config import SYNC_DB_URL'
    
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.py') and file != 'config.py':
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = pattern.sub(replacement, content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f'Updated {path}')

if __name__ == "__main__":
    replace_in_files('.')
