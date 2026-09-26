import psycopg2

def run_update():
    try:
        conn = psycopg2.connect(
            host="127.0.0.1",
            dbname="postgres",
            user="postgres",
            password="12345"
        )
        conn.autocommit = True
        cur = conn.cursor()

        # Update RoleEnum
        try:
            cur.execute("ALTER TYPE roleenum ADD VALUE IF NOT EXISTS 'clinic';")
            print("Added 'clinic' to roleenum")
        except Exception as e:
            print(f"RoleEnum error: {e}")

        # Update SubscriptionPlan
        try:
            cur.execute("ALTER TYPE subscriptionplan ADD VALUE IF NOT EXISTS 'clinic_basic';")
            cur.execute("ALTER TYPE subscriptionplan ADD VALUE IF NOT EXISTS 'clinic_vip';")
            print("Added clinic plans to subscriptionplan")
        except Exception as e:
            print(f"SubscriptionPlan error: {e}")

        # Create clinics table
        try:
            cur.execute("""
            CREATE TABLE IF NOT EXISTS clinics (
                id SERIAL PRIMARY KEY,
                user_id INTEGER UNIQUE REFERENCES users(id),
                description TEXT,
                is_approved BOOLEAN NOT NULL DEFAULT FALSE
            );
            """)
            cur.execute("CREATE INDEX IF NOT EXISTS ix_clinics_id ON clinics (id);")
            print("Created clinics table")
        except Exception as e:
            print(f"Clinics table error: {e}")

        # Alter doctors table
        try:
            cur.execute("ALTER TABLE doctors ADD COLUMN IF NOT EXISTS clinic_id INTEGER REFERENCES clinics(id) ON DELETE SET NULL;")
            print("Added clinic_id to doctors")
        except Exception as e:
            print(f"Doctors table error: {e}")

        # Alter subscriptions table
        try:
            cur.execute("ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS clinic_id INTEGER REFERENCES clinics(id);")
            cur.execute("CREATE INDEX IF NOT EXISTS ix_subscriptions_clinic_id ON subscriptions(clinic_id);")
            cur.execute("ALTER TABLE subscriptions ALTER COLUMN doctor_id DROP NOT NULL;")
            print("Updated subscriptions table")
        except Exception as e:
            print(f"Subscriptions table error: {e}")

        cur.close()
        conn.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

if __name__ == "__main__":
    run_update()
