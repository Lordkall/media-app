import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

DB_URL = 'postgresql+asyncpg://postgres:QubEALBqYtAClfTqFymJbMngiRjFstbM@junction.proxy.rlwy.net:47596/railway'

async def fix():
    engine = create_async_engine(DB_URL)
    async with engine.begin() as conn:
        # Check current columns in doctors
        res = await conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'doctors' ORDER BY column_name"))
        cols = [row[0] for row in res.fetchall()]
        print('Current doctors columns:', cols)
        
        # Add missing columns to doctors table
        doctors_alters = [
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS max_patients_per_day INTEGER DEFAULT 5",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS sponsored_priority INTEGER DEFAULT 99",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS is_sponsored BOOLEAN DEFAULT FALSE",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 0.0",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS consultation_fee FLOAT",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS bio TEXT",
            "ALTER TABLE doctors ADD COLUMN IF NOT EXISTS clinic_info TEXT",
        ]
        
        for sql in doctors_alters:
            col = sql.split('IF NOT EXISTS ')[1].split(' ')[0]
            try:
                await conn.execute(text(sql))
                print(f"doctors.{col}: OK")
            except Exception as e:
                print(f"doctors.{col}: SKIP ({str(e)[:60]})")
        
        # Also fix subscriptions
        sub_alters = [
            "ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL",
            "ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT TRUE",
            "ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS reference_number VARCHAR",
            "ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS screenshot_base64 TEXT",
            "ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS amount_bs FLOAT",
        ]
        for sql in sub_alters:
            col = sql.split('IF NOT EXISTS ')[1].split(' ')[0]
            try:
                await conn.execute(text(sql))
                print(f"subscriptions.{col}: OK")
            except Exception as e:
                print(f"subscriptions.{col}: SKIP ({str(e)[:60]})")
        
        print("Migration complete!")
        
        # Verify
        res2 = await conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'doctors' ORDER BY column_name"))
        cols2 = [row[0] for row in res2.fetchall()]
        print('Final doctors columns:', cols2)

asyncio.run(fix())
