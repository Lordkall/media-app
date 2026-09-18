import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'backend')))

import asyncio
from app.models.base import Base
from app.core.database import engine
from app.models import ExchangeRate

async def init_models():
    print("Creando tablas...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("Tablas creadas.")

async def main():
    await init_models()
    from app.tasks.bcv_scraper import update_db_with_rate
    print("Extrayendo tasa BCV...")
    await update_db_with_rate()
    print("Terminado.")

if __name__ == "__main__":
    asyncio.run(main())

