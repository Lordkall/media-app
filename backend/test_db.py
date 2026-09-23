import sys
import os

# Set up paths for both app and core
base_dir = os.path.abspath('backend')
sys.path.insert(0, base_dir)

from core.config import SYNC_DB_URL
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from app.models.users import User, RoleEnum
from app.models.subscriptions import Subscription

engine = create_engine(SYNC_DB_URL)
Session = sessionmaker(bind=engine)
session = Session()

asts = session.execute(select(User).where(User.role==RoleEnum.ASSISTANT)).scalars().all()
print("=== ASSISTANTS ===")
for a in asts:
    print(f"ID: {a.id}, Email: {a.email}, linked_doc: {a.linked_doctor_id}")

print("\n=== SUBSCRIPTIONS ===")
subs = session.execute(select(Subscription)).scalars().all()
for s in subs:
    print(f"Doc_ID: {s.doctor_id}, Plan: {s.plan}, Status: {s.status}")
