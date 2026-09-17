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
        
        columns = [
            "state VARCHAR(50)",
            "address VARCHAR(255)",
            "avatar_url VARCHAR(255)"
        ]
        
        for col in columns:
            try:
                cur.execute(f"ALTER TABLE users ADD COLUMN {col};")
                print(f"Added column {col}")
            except Exception as e:
                print(f"Error adding {col}: {e}")
                
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

if __name__ == '__main__':
    run_update()
