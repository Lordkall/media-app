import os
import sys

# Aseguramos que la ruta backend esté en sys.path para importar correctamente
base_path = os.path.dirname(os.path.abspath(__file__))
if base_path not in sys.path:
    sys.path.append(base_path)

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from app.models.users import User, RoleEnum
from app.core.security import get_password_hash
from app.core.database import SQLALCHEMY_DATABASE_URL

# Crear engine sincrono para simplificar este script
SYNC_DB_URL = SQLALCHEMY_DATABASE_URL.replace("+asyncpg", "")
engine = create_engine(SYNC_DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def reset_db_users():
    session = SessionLocal()
    try:
        print("Borrando todos los usuarios...")
        # Deshabilitar triggers temporalmente o confiar en ON DELETE CASCADE 
        # Dependiendo del esquema, podríamos necesitar borrar otras tablas relacionadas primero
        # o usar TRUNCATE con CASCADE.
        session.execute(text("TRUNCATE TABLE users RESTART IDENTITY CASCADE;"))
        session.commit()
        
        print("Creando usuario administrador: avilalorenzo07@gmail.com")
        admin_user = User(
            email="avilalorenzo07@gmail.com",
            first_name="Admin",
            last_name="System",
            phone="0000000000",
            hashed_password="Ruffus12.", # La frontend actual usa texto plano
            role=RoleEnum.ADMIN,
            state="Activo",
        )
        session.add(admin_user)
        session.commit()
        print("¡Base de datos limpiada y administrador creado con éxito!")
    except Exception as e:
        session.rollback()
        print(f"Error durante el proceso: {e}")
    finally:
        session.close()

if __name__ == "__main__":
    reset_db_users()
