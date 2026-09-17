from sqlalchemy import create_engine, text
engine = create_engine('postgresql+psycopg2://postgres:12345@127.0.0.1:5432/postgres')
with engine.connect() as conn:
    print(conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'users';")).fetchall())
    print(conn.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'appointments';")).fetchall())
