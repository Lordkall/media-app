import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect("postgresql://postgres:12345@127.0.0.1:5432/postgres")
    try:
        await conn.execute("ALTER TYPE notificationtype ADD VALUE 'DOCTOR_REGISTERED'")
        print("Added DOCTOR_REGISTERED")
    except Exception as e:
        print("DOCTOR_REGISTERED:", e)
        
    try:
        await conn.execute("ALTER TYPE notificationtype ADD VALUE 'DOCTOR_APPROVED'")
        print("Added DOCTOR_APPROVED")
    except Exception as e:
        print("DOCTOR_APPROVED:", e)

    await conn.close()

asyncio.run(main())
