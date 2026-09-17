from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
import os

# Example postgresql async URL
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql+asyncpg://postgres:12345@127.0.0.1:5432/postgres"
)

engine = create_async_engine(SQLALCHEMY_DATABASE_URL, echo=False)

async_session_maker = async_sessionmaker(
    engine, expire_on_commit=False
)

async def get_db():
    async with async_session_maker() as session:
        yield session
