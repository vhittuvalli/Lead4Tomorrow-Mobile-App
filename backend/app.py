from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
import bcrypt
import psycopg

app = Flask(__name__)
CORS(app)

# -----------------------------------
# PostgreSQL connection
# -----------------------------------
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

# -----------------------------------
# Load calendar entries from JSON
# -----------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENTRIES_PATH = os.path.join(BASE_DIR, "storage", "entries.json")

with open(ENTRIES_PATH, "r") as f:
    calendar_entries = json.load(f)


# -----------------------------------
# Routes
# -----------------------------------

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


# ---------- Auth / Profiles ----------

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
        cur.execute(
            """
            INSERT INTO profiles (email, password)
            VALUES (%s, %s)
            ON CONFLICT (email) DO NOTHING
            """,
            (email, hashed.decode("utf-8")),
        )
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
    Upsert profile notification settings.

    Expected from the iOS app now:
      {
        "email": "...",
        "time": "HH:MM",
        "timezone": "<offset hours as string>",
        "method": "email" or "push"
      }

    "phone" and "carrier" are optional and will default to None if not provided.
    """
    data = request.json or {}

    email = data.get("email")
    if not email:
        return jsonify({"error": "email required"}), 400

    # Optional: for backward compatibility; new app likely doesn't send these.
    phone = data.get("phone")
    carrier = data.get("carrier")

    method = data.get("method")
    timezone = data.get("timezone")
    time_val = data.get("time")

    if method is None or timezone is None or time_val is None:
        return jsonify({"error": "method, timezone, and time are required"}), 400

    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO profiles (email, phone, carrier, method, timezone, time)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (email)
            DO UPDATE SET
                phone    = EXCLUDED.phone,
                carrier  = EXCLUDED.carrier,
                method   = EXCLUDED.method,
                timezone = EXCLUDED.timezone,
                time     = EXCLUDED.time
            """,
            (email, phone, carrier, method, timezone, time_val),
        )
        cur.close()

    return jsonify({"status": "success"}), 200


@app.route("/get_profile", methods=["GET"])
def get_profile():
    email = request.args.get("email")
    if not email:
        return jsonify({"error": "email required"}), 400

    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT phone, carrier, method, timezone, time
            FROM profiles
            WHERE email = %s
            """,
            (email,),
        )
        row = cur.fetchone()
        cur.close()

    if row:
        return jsonify(
            {
                "phone": row[0],
                "carrier": row[1],
                "method": row[2],
                "timezone": row[3],
                "time": row[4],
            }
        ), 200

    return jsonify({}), 200


@app.route("/show_profiles", methods=["GET"])
def show_profiles():
    """
    Returns a dict keyed by email for the notification worker script.

    {
      "user@example.com": {
         "phone": ...,
         "carrier": ...,
         "method": ...,
         "timezone": ...,
         "time": ...
      },
      ...
    }
    """
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT email, phone, carrier, method, timezone, time
            FROM profiles
            """
        )
        rows = cur.fetchall()
        cur.close()

    profiles = {
        email: {
            "phone": phone,
            "carrier": carrier,
            "method": method,
            "timezone": timezone,
            "time": time_val,
        }
        for (email, phone, carrier, method, timezone, time_val) in rows
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
            cur.execute(
                "DELETE FROM profiles WHERE email = %s RETURNING email", (email,)
            )
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
    """Helper route so you can verify the deploy has all endpoints."""
    return jsonify(sorted([str(r.rule) for r in app.url_map.iter_rules()])), 200


# Uncomment this for local testing
# if __name__ == "__main__":
#     app.run(debug=True)

