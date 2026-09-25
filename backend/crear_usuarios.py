import requests

URL = "https://media-app-production-dd3f.up.railway.app/api/v1/auth/register"

usuarios = [
    {
        "email": "admin@saludnow.com",
        "first_name": "Admin",
        "last_name": "Principal",
        "phone": "04120000000",
        "state": "Distrito Capital",
        "address": "Sede Central",
        "gender": "Prefiero no decirlo",
        "password": "Password123",
        "role": "admin",
        "specialties": []
    },
    {
        "email": "doctor@saludnow.com",
        "first_name": "Carlos",
        "last_name": "Medina",
        "phone": "04140000001",
        "state": "Miranda",
        "address": "Clínica Caracas",
        "gender": "Masculino",
        "password": "Password123",
        "role": "doctor",
        "specialties": ["Medicina General", "Cardiología"]
    },
    {
        "email": "paciente@saludnow.com",
        "first_name": "Ana",
        "last_name": "Pérez",
        "phone": "04160000002",
        "state": "Carabobo",
        "address": "Valencia",
        "gender": "Femenino",
        "password": "Password123",
        "role": "patient",
        "specialties": []
    }
]

def crear_usuarios():
    print("Intentando crear usuarios de prueba...")
    for u in usuarios:
        try:
            resp = requests.post(URL, json=u)
            if resp.status_code == 200 or resp.status_code == 201:
                print(f"✅ Creado con éxito: {u['email']} (Rol: {u['role']})")
            elif resp.status_code == 400 and "ya está registrado" in resp.text:
                print(f"⚠️ El usuario {u['email']} ya existe en la base de datos.")
            else:
                print(f"❌ Error al crear {u['email']}: Código {resp.status_code} -> {resp.text}")
        except Exception as e:
            print(f"Error de conexión: {e}")

if __name__ == "__main__":
    crear_usuarios()
