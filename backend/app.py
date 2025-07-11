from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os
import datetime
import bcrypt

app = Flask(__name__)
CORS(app)


# Absolute path to storage directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STORAGE_PATH = os.path.join(BASE_DIR, "storage")
DATA_FILE = os.path.join(STORAGE_PATH, "profiles.json")
ENTRIES_PATH = os.path.join(STORAGE_PATH, "entries.json")

# Load entries.json once into memory
with open(ENTRIES_PATH, "r") as f:
    calendar_entries = json.load(f)


@app.route("/", methods=["GET"])
def home():
    return jsonify({"message": "API is running"}), 200

@app.route("/show_profiles", methods=["GET"])
def show_profiles():
    try:
        with open(DATA_FILE, "r") as f:
            profiles = json.load(f)
        return jsonify(profiles), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    
@app.route("/get_entry", methods=["GET"])
def get_entry():
    date_param = request.args.get("date")  # format: M-D
    if not date_param:
        return jsonify({"error": "Date parameter missing"}), 400

    try:
        month, day = map(int, date_param.split("-"))
        month = str(month)
        day = str(day)

        if month in calendar_entries:
            month_data = calendar_entries[month]
            theme = month_data.get("theme", "")
            entry = month_data.get(day, "")
            return jsonify({"theme": theme, "entry": entry}), 200
        else:
            return jsonify({"theme": "", "entry": ""}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/create_profile", methods=["POST"])
def create_profile():
    data = request.get_json()
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        return jsonify({"error": "Email and password are required"}), 400

    try:
        if os.path.exists(DATA_FILE):
            with open(DATA_FILE, "r") as f:
                profiles = json.load(f)
        else:
            profiles = {}

        if email in profiles:
            return jsonify({"error": "Account already exists"}), 400

        # Hash the password
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        profiles[email] = {
            "email": email,
            "password": hashed_password
        }

        with open(DATA_FILE, "w") as f:
            json.dump(profiles, f, indent=2)

        return jsonify({"message": "Account created"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500



@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    input_password = data.get('password')

    with open(DATA_FILE, 'r') as f:
        profiles = json.load(f)

    user = profiles.get(email)
    if not user or 'password' not in user:
        return jsonify({"error": "Invalid email or password"}), 401

    stored_hash = user['password'].encode('utf-8')

    if bcrypt.checkpw(input_password.encode('utf-8'), stored_hash):
        user_copy = {k: v for k, v in user.items() if k != 'password'}
        return jsonify(user_copy), 200
    else:
        return jsonify({"error": "Incorrect password"}), 401


@app.route("/update_profile", methods=["POST"])
def update_profile():
    data = request.json
    email = data.get("email")

    if not email:
        return jsonify({"error": "Email is required"}), 400

    try:
        with open(DATA_FILE, "r") as f:
            profiles = json.load(f)

        if email not in profiles:
            return jsonify({"error": "Profile not found"}), 404

        # Keep the existing hashed password
        password = profiles[email].get("password", "")

        # Update fields
        profiles[email] = {
            "email": email,  # keep email in the profile
            "password": password,
            "phone": data.get("phone", ""),
            "carrier": data.get("carrier", ""),
            "method": data.get("method", "email"),
            "timezone": data.get("timezone", "0"),
            "time": data.get("time", "09:00")
        }

        with open(DATA_FILE, "w") as f:
            json.dump(profiles, f, indent=2)

        return jsonify({"message": "Profile updated successfully"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


"""if __name__ == "__main__":
    # Ensures compatibility with iOS Simulator (localhost resolves to host machine)
    app.run(host="0.0.0.0", port=5000, debug=True)"""

