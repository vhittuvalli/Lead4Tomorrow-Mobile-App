from flask import Flask, jsonify, request
from L4T_calendar import L4T_Calendar  # Adjust the import path if necessary

app = Flask(__name__)
calendar = L4T_Calendar()


@app.route("/get_entry", methods=["GET"])
def get_entry():
    # Get the 'date' parameter from the request (format: 'M-d')
    date_param = request.args.get("date")

    if date_param:
        month, day = date_param.split("-")
        date_dict = {"month": month, "day": day}
    else:
        date_dict = {"month": None, "day": None}

    # Fetch the entry and theme from the Calendar class
    entry_data = calendar.get_entry(date_dict)

    # Ensure the response includes both theme and entry
    if isinstance(entry_data, dict):
        return jsonify(entry_data)
    else:
        # Return an error message if the response is not as expected
        return jsonify({"error": "Failed to retrieve entry or theme"}), 400


if __name__ == "__main__":
    app.run(port=5000, debug=True)
