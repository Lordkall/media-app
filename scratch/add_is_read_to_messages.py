import sys, os
from sqlalchemy import create_engine, text

engine = create_engine("postgresql+psycopg2://postgres:12345@127.0.0.1:5432/postgres")
with engine.begin() as conn:
    try:
        conn.execute(text("ALTER TABLE ticket_messages ADD COLUMN is_read BOOLEAN DEFAULT FALSE;"))
        conn.execute(text("UPDATE ticket_messages SET is_read = TRUE;"))
        print("Column added successfully.")
    except Exception as e:
        print("Error or already exists:", e)
