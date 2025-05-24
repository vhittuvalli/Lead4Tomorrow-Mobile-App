from flask import Flask, request, jsonify
import json
import os
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Use absolute path to avoid issues
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROFILES_PATH = os.path.join(BASE_DIR, "storage", "profiles.json")

@app.route("/create_profile", methods=["POST"])
def create_profile():
    data = request.json
    email = data.get("email")
    password = data.get("password")

    try:
        if not email or not password:
            return jsonify({"error": "Email and password are required"}), 400

        if os.path.exists(PROFILES_PATH):
            with open(PROFILES_PATH, "r") as f:
                profiles = json.load(f)
        else:
            profiles = {}

        if email in profiles:
            return jsonify({"error": "Account already exists"}), 400

        profiles[email] = {"password": password}

        with open(PROFILES_PATH, "w") as f:
            json.dump(profiles, f, indent=2)

        return jsonify({"message": "Account created"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(port=5000, debug=True)

