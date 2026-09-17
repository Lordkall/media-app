import psycopg2
conn = psycopg2.connect('postgresql://postgres:12345@127.0.0.1:5432/postgres')
conn.autocommit = True
cur = conn.cursor()
try:
    cur.execute("ALTER TYPE roleenum RENAME VALUE 'assistant' TO 'ASSISTANT'")
    print("Renamed")
except Exception as e:
    print(e)
    conn.rollback()
    try:
        cur.execute("ALTER TYPE roleenum ADD VALUE 'ASSISTANT'")
        print("Added")
    except Exception as e2:
        print(e2)
