import asyncio
from httpx import AsyncClient

async def test_api():
    async with AsyncClient() as client:
        # Assuming admin is logged in or we can just mock the DB call
        from app.core.database import async_session_maker
        from sqlalchemy import select
        from app.models.notifications import Notification
        from app.models.subscriptions import Subscription

        async with async_session_maker() as db:
            result = await db.scalars(select(Notification).order_by(Notification.id.desc()).limit(5))
            notifications = result.all()

            out = []
            for n in notifications:
                data = {
                    "id": n.id,
                    "action_url": n.action_url,
                    "payment_details": None
                }
                if n.action_url and n.action_url.startswith("approve_subscription:"):
                    sub_id = int(n.action_url.split(":")[1])
                    sub = await db.scalar(select(Subscription).where(Subscription.id == sub_id))
                    if sub:
                        data["payment_details"] = {
                            "sub_id": sub.id,
                            "reference_number": sub.reference_number,
                            "amount_bs": sub.amount_bs,
                            "screenshot_base64": "YES" if sub.screenshot_base64 else "NO"
                        }
                out.append(data)
            
            for o in out:
                print(o)

if __name__ == '__main__':
    asyncio.run(test_api())
