import psycopg2

def run_update():
    try:
        conn = psycopg2.connect(
            "postgresql://postgres:nPWDQARrlHWjEGyACJJxfdTEGSKKEkRr@altaria.proxy.rlwy.net:21931/railway"
        )
        conn.autocommit = True
        cur = conn.cursor()
        
        try:
            cur.execute("ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255);")
            print("Added column fcm_token")
        except Exception as e:
            print(f"Error adding fcm_token (might already exist): {e}")
                
        cur.close()
        conn.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

if __name__ == '__main__':
    run_update()
