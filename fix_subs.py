import sys
import os
sys.path.append(os.path.abspath('backend'))

from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from app.models.doctors import Doctor
from app.models.subscriptions import Subscription, SubscriptionStatus

SYNC_DB_URL = 'postgresql+psycopg2://postgres:12345@127.0.0.1:5432/postgres'
engine = create_engine(SYNC_DB_URL)
Session = sessionmaker(bind=engine)

with Session() as session:
    subs = session.execute(
        select(Subscription).join(Doctor).where(
            Subscription.status == SubscriptionStatus.ACTIVE,
            Doctor.is_sponsored == False,
            Doctor.is_featured == False
        )
    ).scalars().all()
    print(f'Found {len(subs)} zombie active subscriptions')
    for s in subs:
        s.status = SubscriptionStatus.CANCELLED
    session.commit()
    print('Fixed.')
