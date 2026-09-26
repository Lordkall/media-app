import asyncio
import os
import sys

# Agrega la raíz del backend al path para poder importar
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.database import SQLALCHEMY_DATABASE_URL

async def migrate():
    print(f"Connecting to database...")
    engine = create_async_engine(SQLALCHEMY_DATABASE_URL)
    async with engine.begin() as conn:
        print("Checking/Adding reference_number...")
        try:
            await conn.execute(text("ALTER TABLE subscriptions ADD COLUMN reference_number VARCHAR"))
            print("OK")
        except Exception as e:
            print(f"Skipped (already exists?): {e}")
            
        print("Checking/Adding screenshot_base64...")
        try:
            await conn.execute(text("ALTER TABLE subscriptions ADD COLUMN screenshot_base64 TEXT"))
            print("OK")
        except Exception as e:
            print(f"Skipped (already exists?): {e}")
            
        print("Checking/Adding amount_bs...")
        try:
            await conn.execute(text("ALTER TABLE subscriptions ADD COLUMN amount_bs FLOAT"))
            print("OK")
        except Exception as e:
            print(f"Skipped (already exists?): {e}")
            
    print("Migración completada. Ya puedes cerrar este script.")

if __name__ == "__main__":
    asyncio.run(migrate())
