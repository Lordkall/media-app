import psycopg2

DB_URL = "postgresql://postgres:12345@127.0.0.1:5432/postgres"

def main():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = True
    cur = conn.cursor()

    try:
        # Get all active subscriptions and their plans
        cur.execute("SELECT doctor_id, plan FROM subscriptions WHERE status = 'ACTIVE';")
        subs = cur.fetchall()
        
        count = 0
        for doc_id, plan in subs:
            is_sponsored = (plan == 'SPONSORED')
            is_featured = (plan == 'FEATURED')
            priority = 1 if is_sponsored else 99
            
            cur.execute("""
                UPDATE doctors 
                SET is_sponsored = %s, is_featured = %s, sponsored_priority = %s, is_approved = TRUE
                WHERE id = %s
            """, (is_sponsored, is_featured, priority, doc_id))
            
            count += cur.rowcount

        print(f"Actualizados {count} doctores con suscripciones activas.")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    main()
