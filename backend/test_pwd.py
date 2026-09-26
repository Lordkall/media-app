import asyncio
from sqlalchemy import select
from app.core.database import async_session_maker
from app.models.users import User
from app.core.security import verify_password

async def test():
    async with async_session_maker() as session:
        query = select(User).where(User.email == 'doctor@saludnow.com')
        res = await session.execute(query)
        u = res.scalars().first()
        if u:
            print("User found:", u.email)
            print("Password hash:", u.hashed_password)
            valid = verify_password('Password123', u.hashed_password)
            print("Password Valid:", valid)
        else:
            print("User not found!")

if __name__ == '__main__':
    asyncio.run(test())
