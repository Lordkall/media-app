from sqlalchemy import create_engine, text

def run():
    engine = create_engine('postgresql://postgres:12345@127.0.0.1:5432/postgres')
    with engine.begin() as conn:
        try:
            conn.execute(text("ALTER TYPE notificationtype ADD VALUE 'SUPPORT_MESSAGE'"))
            print("Successfully added")
        except Exception as e:
            print("Error or already added:", e)

if __name__ == '__main__':
    run()
