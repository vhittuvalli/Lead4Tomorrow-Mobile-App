from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
import bcrypt
import psycopg

app = Flask(__name__)
CORS(app)

# PostgreSQL credentials from Render
DB_HOST = "dpg-d1s18nje5dus73fm1qeg-a"
DB_NAME = "lead4tomorrow"
DB_USER = "lead4tomorrow_user"
DB_PASSWORD = os.getenv("DB_PASSWORD")

def get_connection():
    return psycopg.connect(
        host=DB_HOST,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        autocommit=True
    )

# Load calendar entries from entries.json
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENTRIES_PATH = os.path.join(BASE_DIR, "storage", "entries.json")
with open(ENTRIES_PATH, "r") as f:
    calendar_entries = json.load(f)

@app.route("/", methods=["GET"])
def home():
    return jsonify({"message": "API is running"}), 200

@app.route("/get_entry", methods=["GET"])
def get_entry():
    month = request.args.get("month")
    day = request.args.get("day")

    try:
        if not month:
            return jsonify({"error": "Missing month"}), 400

        if month in calendar_entries:
            theme = calendar_entries[month].get("theme", "")
            entry = calendar_entries[month].get(day, "") if day else ""
            return jsonify({"theme": theme, "entry": entry}), 200
        else:
            return jsonify({"theme": "", "entry": ""}), 200
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
# ADD THIS to your Flask app (e.g., below show_profiles)

@app.route("/delete_profile", methods=["POST", "DELETE"])
def delete_profile():
    """
    Deletes a profile by email.
    Accepts:
      - POST with JSON body: {"email": "<user@example.com>"}
      - DELETE with ?email=<...> query string
      - POST form-encoded: email=<...>
    Returns 200 whether deleted or not found (idempotent UX).
    """
    # Get email from JSON, query param, or form
    email = None
    if request.is_json:
        data = request.get_json(silent=True) or {}
        email = data.get("email")
    if not email:
        email = request.args.get("email") or request.form.get("email")

    if not email:
        return jsonify({"error": "email required"}), 400

    try:
        with get_connection() as conn:
            cur = conn.cursor()
            cur.execute("DELETE FROM profiles WHERE email = %s RETURNING email", (email,))
            deleted = cur.fetchone()
            cur.close()
        if deleted:
            return jsonify({"status": "deleted", "email": email}), 200
        else:
            return jsonify({"status": "not_found", "email": email}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# TEMP helper: list routes so you can verify the deploy has the new endpoint
@app.route("/routes", methods=["GET"])
def routes():
    return jsonify(sorted([str(r.rule) for r in app.url_map.iter_rules()]))

# Uncomment this for local testing
# if __name__ == "__main__":
#     app.run(debug=True)

