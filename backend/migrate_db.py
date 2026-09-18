import sys
import os
import asyncio
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

sys.path.insert(0, os.path.abspath('backend'))
from app.models import Base

OLD_DB_URL = "postgresql://media_db_wy3o_user:FOselX3i2fMATLvPuw5T3kA8OV4zmDuU@dpg-dallji2jnfac73a09p10-a.oregon-postgres.render.com/media_db_wy3o?sslmode=require"
NEW_DB_URL = "postgresql://postgres:nPWDQARrlHWjEGyACJJxfdTEGSKKEkRr@altaria.proxy.rlwy.net:21931/railway"

def migrate():
    print("Connecting to New DB...")
    new_engine = create_engine(NEW_DB_URL)
    with new_engine.connect() as conn:
        print("Railway DB connected!")

    print("Creating tables in New DB...")
    Base.metadata.create_all(new_engine)
    print("Schema initialized successfully!")
    sys.exit(0)

    print("Creating tables in New DB...")
    Base.metadata.create_all(new_engine)

    # Tables to migrate
    tables = [
        'users', 'doctors', 'tasas_de_cambio', 'availabilities', 'notifications', 
        'password_reset_tokens', 'patients', 'subscriptions', 'support_tickets', 
        'appointments', 'ticket_messages'
    ]

    with new_engine.begin() as new_conn:
        new_conn.execute(text("SET session_replication_role = 'replica';"))
        
        with old_engine.connect() as old_conn:
            for table_name in tables:
                print(f"Migrating table {table_name}...")
                result = old_conn.execute(text(f"SELECT * FROM {table_name}"))
                rows = result.fetchall()
                if not rows:
                    continue
                
                columns = list(result.keys())
                
                # Insert rows
                for row in rows:
                    placeholders = ', '.join([':' + c for c in columns])
                    cols = ', '.join(columns)
                    insert_stmt = text(f"INSERT INTO {table_name} ({cols}) VALUES ({placeholders})")
                    # Use row.tuple() or row._mapping for modern SQLAlchemy
                    new_conn.execute(insert_stmt, row._mapping)
                    
        new_conn.execute(text("SET session_replication_role = 'origin';"))
        
    print("Migration completed successfully!")

if __name__ == "__main__":
    migrate()
