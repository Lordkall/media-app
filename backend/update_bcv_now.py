import asyncio
from sqlalchemy import select
from app.core.database import async_session_maker
from app.models.exchange_rate import ExchangeRate

async def main():
    async with async_session_maker() as session:
        result = await session.execute(
            select(ExchangeRate).where(
                ExchangeRate.moneda_origen == 'USD',
                ExchangeRate.moneda_destino == 'VES'
            )
        )
        rate = result.scalar_one_or_none()
        if rate:
            rate.tasa = 855.6625
        await session.commit()
        print("Rate updated to 855.6625")

if __name__ == "__main__":
    asyncio.run(main())
