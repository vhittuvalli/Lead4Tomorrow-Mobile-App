from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import bcrypt
import psycopg
from calendar_data import calendar_data

app = Flask(__name__)
CORS(app)

# PostgreSQL credentials from Render
DB_HOST = "dpg-d1s18nje5dus73fm1qeg-a"
DB_NAME = "lead4tomorrow"
DB_USER = "lead4tomorrow_user"
DB_PASSWORD = os.getenv("DB_PASSWORD")  # Set in Render

def get_connection():
    return psycopg.connect(
        host=DB_HOST,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        autocommit=True
    )

@app.route("/get_entry", methods=["GET"])
def get_entry():
    month = request.args.get("month")
    day = request.args.get("day")
    try:
        entry = calendar_data.get(month, {}).get(day, None)
        if entry:
            return jsonify(entry)
        return jsonify({"error": "Entry not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/create_profile", methods=["POST"])
def create_profile():
    data = request.json
    email = data["email"]
    password = data["password"]
    hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())

    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO profiles (email, password) 
            VALUES (%s, %s) 
            ON CONFLICT (email) DO NOTHING
        """, (email, hashed.decode("utf-8")))
        cur.close()

    return jsonify({"message": "Account created"})

@app.route("/login", methods=["POST"])
def login():
    data = request.json
    email = data["email"]
    password = data["password"]

    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT password FROM profiles WHERE email = %s", (email,))
        result = cur.fetchone()
        cur.close()

    if result and bcrypt.checkpw(password.encode("utf-8"), result[0].encode("utf-8")):
        return jsonify({"message": "Login successful"})
    return jsonify({"error": "Invalid credentials"}), 401

@app.route("/update_profile", methods=["POST"])
def update_profile():
    data = request.json
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO profiles (email, phone, carrier, method, timezone, time)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (email)
            DO UPDATE SET
                phone = EXCLUDED.phone,
                carrier = EXCLUDED.carrier,
                method = EXCLUDED.method,
                timezone = EXCLUDED.timezone,
                time = EXCLUDED.time
        """, (
            data["email"], data["phone"], data["carrier"],
            data["method"], data["timezone"], data["time"]
        ))
        cur.close()
    return jsonify({"status": "success"})

@app.route("/get_profile", methods=["GET"])
def get_profile():
    email = request.args.get("email")
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT phone, carrier, method, timezone, time 
            FROM profiles 
            WHERE email = %s
        """, (email,))
        row = cur.fetchone()
        cur.close()

    if row:
        return jsonify({
            "phone": row[0],
            "carrier": row[1],
            "method": row[2],
            "timezone": row[3],
            "time": row[4]
        })
    return jsonify({})

@app.route("/show_profiles", methods=["GET"])
def show_profiles():
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT email, phone, carrier, method, timezone, time 
            FROM profiles
        """)
        rows = cur.fetchall()
        cur.close()

    profiles = {
        email: {
            "phone": phone,
            "carrier": carrier,
            "method": method,
            "timezone": timezone,
            "time": time
        } for (email, phone, carrier, method, timezone, time) in rows
    }
    return jsonify(profiles)

# Uncomment this for local testing
# if __name__ == "__main__":
#     app.run(debug=True)

