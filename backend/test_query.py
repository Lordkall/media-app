import asyncio
from app.core.database import SessionLocal
from sqlalchemy import select, or_
from app.models.doctors import Doctor
from app.models.users import User

async def main():
    async with SessionLocal() as db:
        query = select(Doctor, User).join(User, Doctor.user_id == User.id).where(
            Doctor.clinic_id.is_(None),
            or_(
                Doctor.clinic_join_status.is_(None),
                Doctor.clinic_join_status.notin_(["pending", "invited"])
            ),
            User.state == "Trujillo"
        )
        rows = await db.execute(query.limit(20))
        docs = rows.all()
        print(len(docs))

if __name__ == "__main__":
    asyncio.run(main())
