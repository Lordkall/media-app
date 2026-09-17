import asyncio
import os
from sqlalchemy.ext.asyncio import create_async_engine
from app.models.base import Base
from app.models.password_reset import PasswordResetToken
from app.core.database import SQLALCHEMY_DATABASE_URL

DATABASE_URL = SQLALCHEMY_DATABASE_URL

# Crearemos el engine solo para generar la tabla
# Nota: Si tu app usa sqlalchemy síncrona en lugar de asyncpg, cambia la URL.

async def create_table():
    print(f"Connecting to database to create password_reset_tokens table...")
    engine = create_async_engine(DATABASE_URL, echo=True)
    async with engine.begin() as conn:
        # Create only the PasswordResetToken table, other tables should already exist
        await conn.run_sync(PasswordResetToken.__table__.create, checkfirst=True)
    
    print("Table password_reset_tokens created successfully!")
    await engine.dispose()

if __name__ == "__main__":
    try:
        asyncio.run(create_table())
    except Exception as e:
        print(f"Error creating table async, trying sync... ({e})")
        
        # Fallback a síncrono
        from sqlalchemy import create_engine
        SYNC_DB_URL = DATABASE_URL.replace("+asyncpg", "")
        sync_engine = create_engine(SYNC_DB_URL, echo=True)
        PasswordResetToken.__table__.create(sync_engine, checkfirst=True)
        print("Table password_reset_tokens created successfully (sync)!")
