import asyncio
from sqlalchemy import text
from app.core.database import async_session_maker

async def main():
    async with async_session_maker() as db:
        res = await db.execute(text("SELECT enum_range(NULL::roleenum)"))
        print(res.scalar())

if __name__ == "__main__":
    asyncio.run(main())
