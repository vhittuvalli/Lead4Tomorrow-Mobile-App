import json
import datetime
import os


class Calendar:
    "Contains functions used for the calendar app back-end"

    entries_filepath = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "data", "entries.json"))

    def __init__(self):
        # Load all calendar entries into a dictionary
        with open(self.entries_filepath, "r") as file:
            self.entries = dict(json.load(file))

    def get_today(self) -> dict[str, str]:
        "Returns the current month and day in a dictionary format; e.g. `{'month': '1', 'day': '1'}`"
        today = datetime.date.today()
        return {"month": str(today.month), "day": str(today.day)}

    def get_entry(self, date={"month": None, "day": None}) -> dict:
        """Returns the entry for a given day with the theme of the month.

        `date`: dictionary containing the specified date. The format should be `{'month': '6', 'day': '24'}`.

        If `month` and `day` are `None`, returns the current day's entry with the theme.
        If `day` is `None` but `month` is specified, returns that month's theme.
        """
        today = self.get_today()

        if date["month"] is None:
            month = today["month"]
            day = today["day"]
        else:
            month = date["month"]
            day = date.get("day")

        if day is None:
            return {
                "theme": self.entries[month]["theme"]
            }
        else:
            return {
                "theme": self.entries[month]["theme"],
                "entry": self.entries[month][day]
            }

    def modify_entry(self, date: dict[str, str], new_entry: str) -> None:
        """Modifies an entry in the `entries.json` file.

        `date`: dictionary containing the specified date. The format should be `{'month': '6', 'day': '24'}`. If `day` is `None` but `month` is specified, edit's that month's theme.

        `new_entry`: str containing the new entry.
        """
        # Edit entry in dict
        if date["day"] is None:
            self.entries[date["month"]]["theme"] = new_entry
        else:
            self.entries[date["month"]][date["day"]] = new_entry

        # Write to JSON file
        with open(self.entries_filepath, "w") as file:
            file.write(json.dumps(self.entries, indent=4))
