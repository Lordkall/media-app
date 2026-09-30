import urllib.request, urllib.parse, json, ssl

ctx = ssl.create_default_context()
EMAIL = 'clinica@saludnow.com'
PASSWORD = 'Password123'

# Login
req = urllib.request.Request(
    'https://saludnow.site/api/v1/auth/login',
    data=urllib.parse.urlencode({'username': EMAIL, 'password': PASSWORD}).encode(),
    headers={'Content-Type': 'application/x-www-form-urlencoded'},
    method='POST'
)
r = urllib.request.urlopen(req, context=ctx)
token = json.loads(r.read())['access_token']
headers = {'Authorization': 'Bearer ' + token}
print('LOGIN OK')

# /users/me
r = urllib.request.urlopen(urllib.request.Request('https://saludnow.site/api/v1/users/me', headers=headers), context=ctx)
me = json.loads(r.read())
print('\n=== /users/me ===')
print('  role:', me.get('role'))
print('  state:', me.get('state'))
print('  first_name:', me.get('first_name'))

# /clinics/
r = urllib.request.urlopen(urllib.request.Request('https://saludnow.site/api/v1/clinics/', headers=headers), context=ctx)
clinics = json.loads(r.read())
print('\n=== GET /clinics/ (publico) ===')
print('  Total:', len(clinics))
for c in clinics:
    print('  -', c.get('first_name'), '| state:', c.get('state'), '| approved:', c.get('is_approved'))

# /admin/doctors
try:
    r = urllib.request.urlopen(urllib.request.Request('https://saludnow.site/api/v1/admin/doctors', headers=headers), context=ctx)
    docs = json.loads(r.read())
    print('\n=== GET /admin/doctors ===')
    print('  Total:', len(docs))
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print('\n=== GET /admin/doctors ERROR ===')
    print('  Status:', e.code)
    print('  Body:', body[:300])

print('\n=== DIAGNOSTICO FILTRO ===')
user_state = me.get('state')
print('  Estado del usuario logueado:', user_state)
for c in clinics:
    clinic_state = c.get('state')
    match = clinic_state == user_state
    print('  Clinica', c.get('first_name'), '- state:', clinic_state, '- coincide:', match)
