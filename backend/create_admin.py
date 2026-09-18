import sys
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, os.path.abspath('backend'))
from app.models import User
from app.core.security import get_password_hash

NEW_DB_URL = "postgresql://postgres:nPWDQARrlHWjEGyACJJxfdTEGSKKEkRr@altaria.proxy.rlwy.net:21931/railway"

engine = create_engine(NEW_DB_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

db = SessionLocal()

admin = db.query(User).filter(User.email == "admin@saludnow.com").first()
if not admin:
    admin = User(
        email="admin@saludnow.com",
        first_name="Administrador",
        last_name="SaludNow",
        phone="+1234567890",
        hashed_password=get_password_hash("admin123"),
        role="admin",
        state="active"
    )
    db.add(admin)
    db.commit()
    print("Admin user created!")
else:
    print("Admin user already exists!")
db.close()
