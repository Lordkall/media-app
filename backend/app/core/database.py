from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
import os

# Example postgresql async URL
raw_db_url = os.getenv(
    "DATABASE_URL", 
    "postgresql+asyncpg://postgres:12345@127.0.0.1:5432/postgres"
)

# Render provee URLs que empiezan con postgresql:// en lugar de postgresql+asyncpg://
if raw_db_url.startswith("postgresql://"):
    raw_db_url = raw_db_url.replace("postgresql://", "postgresql+asyncpg://", 1)

SQLALCHEMY_DATABASE_URL = raw_db_url

engine = create_async_engine(SQLALCHEMY_DATABASE_URL, echo=False)

async_session_maker = async_sessionmaker(
    engine, expire_on_commit=False
)

async def get_db():
    async with async_session_maker() as session:
        yield session
