from flask import Flask, jsonify, request
from calendar import Calendar  # Assuming your Calendar class is in 'calendar_backend.py'

app = Flask(__name__)
calendar = Calendar()

@app.route('/get_entry', methods=['GET'])
def get_entry():
    # Get the 'date' parameter from the request (format: 'M-d')
    date_param = request.args.get('date')
    
    if date_param:
        month, day = date_param.split('-')
        date_dict = {"month": month, "day": day}
    else:
        date_dict = {"month": None, "day": None}

    # Fetch the entry from the Calendar class
    entry = calendar.get_entry(date_dict)
    
    # Return the entry as an array
    if isinstance(entry, str):
        return jsonify([entry])
    elif isinstance(entry, list):
        return jsonify(entry)
    else:
        return jsonify([])

if __name__ == '__main__':
    app.run(port=5000, debug=True)
