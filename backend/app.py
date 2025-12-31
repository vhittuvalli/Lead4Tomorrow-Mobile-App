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


# ----------------------------
# Calendar entries from shifted JSON
# ----------------------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Point directly to the shifted entries file
ENTRIES_PATH = os.path.join(BASE_DIR, "storage", "entries_shifted.json")

with open(ENTRIES_PATH, "r", encoding="utf-8") as f:
    calendar_entries = json.load(f)


@app.route("/", methods=["GET"])
def home():
    return jsonify({"message": "API is running"}), 200


@app.route("/get_entry", methods=["GET"])
def get_entry():
    """
    Returns theme + entry for a given month/day directly from entries_shifted.json.

    Query params:
      - month: "1".."12"
      - day: "1".."31" (optional; if missing, returns only theme)
    """
    month = request.args.get("month")
    day = request.args.get("day")  # may be None

    if not month:
        return jsonify({"error": "Missing month"}), 400

    try:
        if month in calendar_entries:
            theme = calendar_entries[month].get("theme", "")
            entry = calendar_entries[month].get(day, "") if day else ""
            return jsonify({"theme": theme, "entry": entry}), 200
        else:
            # Month not found, return empty but 200 (same behavior as before)
            return jsonify({"theme": "", "entry": ""}), 200
    except Exception as e:
        app.logger.exception(f"Error in /get_entry for month={month}, day={day}: {e}")
        return jsonify({"error": "Internal server error"}), 500


# ----------------------------
# Auth / Profiles
# ----------------------------

@app.route("/create_profile", methods=["POST"])
def create_profile():
    data = request.json or {}
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        return jsonify({"error": "email and password required"}), 400

    hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())

    with get_connection() as conn:
        cur = conn.cursor()
        # Only set email + password here; other fields can be updated later
        cur.execute("""
            INSERT INTO profiles (email, password)
            VALUES (%s, %s)
            ON CONFLICT (email) DO NOTHING
        """, (email, hashed.decode("utf-8")))
        cur.close()

    return jsonify({"message": "Account created"}), 200


@app.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        return jsonify({"error": "email and password required"}), 400

    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT password FROM profiles WHERE email = %s", (email,))
        result = cur.fetchone()
        cur.close()

    if result and bcrypt.checkpw(password.encode("utf-8"), result[0].encode("utf-8")):
        return jsonify({"message": "Login successful"}), 200
    return jsonify({"error": "Invalid credentials"}), 401


@app.route("/update_profile", methods=["POST"])
def update_profile():
    """
    Upserts notification preferences and (optionally) device_token for a profile.

    Expected JSON:
    {
      "email": "...",
      "method": "email" | "push",
      "timezone": "-5",        # string hours offset
      "time": "09:00",         # HH:MM
      "device_token": "..."    # optional
    }

    Important behavior:
    - device_token is ONLY updated if provided and non-empty.
      This prevents wiping a valid token when the client posts settings without a token.
    """
    data = request.json or {}
    email = data.get("email")
    method = data.get("method")
    timezone = data.get("timezone")
    time_val = data.get("time")
    device_token = data.get("device_token")

    if not email:
        return jsonify({"error": "email required"}), 400

    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO profiles (email, method, timezone, time, device_token)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (email)
            DO UPDATE SET
                method = EXCLUDED.method,
                timezone = EXCLUDED.timezone,
                time = EXCLUDED.time,
                device_token = COALESCE(NULLIF(EXCLUDED.device_token, ''), profiles.device_token)
        """, (email, method, timezone, time_val, device_token))
        cur.close()

    return jsonify({"status": "success"}), 200


@app.route("/register_device", methods=["POST"])
def register_device():
    """
    Sets/updates device_token for an existing profile.
    Expected JSON:
    {
      "email": "...",
      "device_token": "64-char hex token"
    }

    This is called by the app when APNs returns a token.
    """
    data = request.json or {}
    email = data.get("email")
    device_token = (data.get("device_token") or "").strip()

    if not email:
        return jsonify({"error": "email required"}), 400
    if not device_token:
        return jsonify({"error": "device_token required"}), 400

    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO profiles (email, device_token)
            VALUES (%s, %s)
            ON CONFLICT (email)
            DO UPDATE SET device_token = EXCLUDED.device_token
        """, (email, device_token))
        cur.close()

    return jsonify({"status": "success"}), 200


@app.route("/get_profile", methods=["GET"])
def get_profile():
    email = request.args.get("email")
    if not email:
        return jsonify({"error": "email required"}), 400

    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT method, timezone, time, device_token
            FROM profiles
            WHERE email = %s
        """, (email,))
        row = cur.fetchone()
        cur.close()

    if row:
        return jsonify({
            "method": row[0],
            "timezone": row[1],
            "time": row[2],
            "device_token": row[3],
        }), 200

    return jsonify({}), 200


@app.route("/show_profiles", methods=["GET"])
def show_profiles():
    """
    Returns all profiles as a dict keyed by email.
    Includes device_token for push.
    """
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT email, phone, carrier, method, timezone, time, device_token
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
            "time": time,
            "device_token": device_token
        }
        for (email, phone, carrier, method, timezone, time, device_token) in rows
    }

    return jsonify(profiles), 200


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


@app.route("/routes", methods=["GET"])
def routes():
    return jsonify(sorted([str(r.rule) for r in app.url_map.iter_rules()])), 200


# Uncomment for local testing
# if __name__ == "__main__":
#     app.run(debug=True)

