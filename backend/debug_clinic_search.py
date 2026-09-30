"""
Script de diagnóstico: ¿Por qué no aparece la clínica en búsqueda?
Ejecutar con: python debug_clinic_search.py
"""
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select, text

# Importar config
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from app.core.config import settings
from app.models.clinics import Clinic
from app.models.users import User
from app.models.subscriptions import Subscription, SubscriptionStatus, SubscriptionPlan

async def main():
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        print("=" * 60)
        print("DIAGNÓSTICO: Clínicas en la base de datos")
        print("=" * 60)

        # 1. Todas las clínicas con su usuario
        all_clinics = await db.execute(
            select(Clinic, User)
            .join(User, Clinic.user_id == User.id)
        )
        rows = all_clinics.all()
        
        print(f"\nTotal de clínicas registradas: {len(rows)}")
        print("-" * 60)
        
        for c, u in rows:
            print(f"\n🏥 Clínica ID={c.id} | User ID={u.id}")
            print(f"   Nombre:      {u.first_name} {u.last_name}")
            print(f"   Email:       {u.email}")
            print(f"   Estado:      '{u.state}'")
            print(f"   Dirección:   '{u.address}'")
            print(f"   is_approved: {c.is_approved}")
            print(f"   avatar_url:  {u.avatar_url}")
            
            # Check subscription
            sub = await db.scalar(
                select(Subscription).where(
                    Subscription.clinic_id == c.id,
                    Subscription.status == SubscriptionStatus.ACTIVE
                )
            )
            if sub:
                print(f"   Suscripción: ACTIVA - plan={sub.plan.value}, vence={sub.end_date}")
                print(f"   Es VIP:      {sub.plan == SubscriptionPlan.CLINIC_VIP}")
            else:
                print(f"   Suscripción: NINGUNA ACTIVA")
            
            # Verify if it would appear in /clinics endpoint
            would_appear = c.is_approved
            print(f"   ¿Aparece en /clinics? {'✅ SÍ' if would_appear else '❌ NO (is_approved=False)'}")
        
        print("\n" + "=" * 60)
        print("ENDPOINT /clinics - simulando respuesta:")
        print("=" * 60)
        
        query = select(Clinic, User, Subscription).join(User, Clinic.user_id == User.id).outerjoin(
            Subscription, (Subscription.clinic_id == Clinic.id) & (Subscription.status == SubscriptionStatus.ACTIVE)
        ).where(Clinic.is_approved == True)
        result = await db.execute(query)
        approved_rows = result.all()
        
        print(f"\nClínicas aprobadas que devuelve /clinics: {len(approved_rows)}")
        for c, u, s in approved_rows:
            is_vip = s and s.plan == SubscriptionPlan.CLINIC_VIP
            print(f"  - {u.first_name} | state='{u.state}' | is_vip={is_vip}")
        
        if len(approved_rows) == 0:
            print("  ⚠️  NINGUNA. El filtro is_approved=True excluye todas las clínicas.")

    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(main())
