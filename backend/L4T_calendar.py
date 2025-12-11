import json
import datetime
import utils
import logging

log = logging.getLogger(__name__)
utils.config_log()


class L4T_Calendar:
    """Contains functions used for the calendar app back-end"""

    # ✅ Point to backend/storage/entries_shifted.json so it works on Render
    entries_filepath = utils.create_path("backend", "storage", "entries_shifted.json")

    def __init__(self):
        # Load all calendar entries into a dictionary
        with open(self.entries_filepath, "r", encoding="utf-8") as file:
            self.entries = dict(json.load(file))

    def get_curr_time(self, timezone: int = 0):
        """Returns the current time as a `datetime` object.

        `timezone`: hour difference from UTC. For example, Pacific Standard Time would be `-8`.
        """
        return datetime.datetime.now(
            datetime.timezone(datetime.timedelta(hours=timezone))
        )

    def get_today(self, timezone: int = 0, long_form: bool = False) -> dict[str, str]:
        """Returns the current month and day in a dictionary format.

        `timezone`: hour difference from UTC. For example, Pacific Standard Time would be `-8`.
        `long_form`: If `True`, returns the name of the month and day.
        """
        today = self.get_curr_time(timezone)

        if not long_form:
            return {"month": today.strftime("%-m"), "day": today.strftime("%-d")}
        else:
            return {"month": today.strftime("%B"), "day": today.strftime("%A")}

    def get_entry(self, date: dict) -> dict:
        """Returns the entry for a given day with the theme of the month.

        Assumes `entries_shifted.json` already contains the correct, shifted content.
        No extra combining or shifting is done here.
        """
        try:
            month = str(int(date["month"]))  # normalize month key
            raw_day = date.get("day")
            day = str(int(raw_day)) if raw_day else None

            month_entries = self.entries.get(month)
            if not month_entries:
                return {"theme": "", "entry": ""}

            # Only theme requested (no specific day)
            if day is None:
                return {"theme": month_entries.get("theme", "")}

            # Direct lookup: shifted JSON is already preprocessed
            entry_text = month_entries.get(day, "")

            return {
                "theme": month_entries.get("theme", ""),
                "entry": entry_text,
            }

        except KeyError as err:
            log.critical(f"`get_entry` failed with input date={date}: {err}")
            return {"theme": "", "entry": ""}
        except Exception as err:
            log.critical(f"`get_entry` unexpected error with date={date}: {err}")
            return {"theme": "", "entry": ""}

    def modify_entry(self, date: dict[str, str], new_entry: str) -> None:
        """Modifies an entry in the `entries_shifted.json` file.

        `date`: dictionary containing the specified date. Format: `{'month': '6', 'day': '24'}`.
        `new_entry`: str containing the new entry.
        """
        month = str(int(date["month"]))
        day = str(int(date["day"])) if date["day"] else None

        # Make sure the month exists
        if month not in self.entries:
            self.entries[month] = {"theme": ""}

        if day is None:
            # Update theme only
            self.entries[month]["theme"] = new_entry
        else:
            # Update specific day
            self.entries[month][day] = new_entry

        # Write to JSON file
        with open(self.entries_filepath, "w", encoding="utf-8") as file:
            file.write(json.dumps(self.entries, indent=4))


if __name__ == "__main__":
    log = logging.getLogger(__name__)
    logging.basicConfig(filename=utils.create_log_path(__file__), level=logging.INFO)

