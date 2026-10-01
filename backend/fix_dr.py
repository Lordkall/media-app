import os
import re

def process_file(path):
    if not os.path.exists(path): return
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Matches 'Dr. ${var['first_name']} ...' or 'Dr. ${var['first_name'] ?? ...}'
    def replacer(m):
        var = m.group(1)
        return f"${{({var}['gender'] == 'Femenino' || {var}['gender'] == 'Femenina') ? 'Dra.' : 'Dr.'}} ${{ {var}['first_name']"
    
    # We will just do a slightly manual replacement for each file since the patterns vary slightly.
    content = re.sub(r"'Dr\.\s*\$\{\s*([a-zA-Z0-9_]+)\['first_name'\]", replacer, content)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

files = [
    'frontend_flutter/lib/screens/doctor_profile_screen.dart',
    'frontend_flutter/lib/screens/clinic_profile_screen.dart',
    'frontend_flutter/lib/screens/clinic_account_screens.dart',
    'frontend_flutter/lib/screens/browse_doctors_tab.dart',
    'frontend_flutter/lib/screens/agendar_cita_tab.dart',
    'frontend_flutter/lib/screens/admin_subscriptions_tab.dart'
]

for file in files:
    process_file(file)
