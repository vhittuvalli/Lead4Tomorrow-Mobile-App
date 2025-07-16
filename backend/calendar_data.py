import json
import os

BASE_DIR = os.path.dirname(__file__)
ENTRIES_FILE = os.path.join(BASE_DIR, "storage", "entries.json")

with open(ENTRIES_FILE, "r") as f:
    calendar_data = json.load(f)
