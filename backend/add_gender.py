import os

def add_gender(path):
    if not os.path.exists(path): return
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace('"last_name": user.last_name,', '"last_name": user.last_name, "gender": user.gender,')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

add_gender('backend/app/api/v1/endpoints/admin.py')
add_gender('backend/app/api/v1/endpoints/clinics.py')
add_gender('backend/app/api/v1/endpoints/doctors.py')
add_gender('backend/app/api/v1/endpoints/search.py')
add_gender('backend/app/api/v1/endpoints/appointments.py')
