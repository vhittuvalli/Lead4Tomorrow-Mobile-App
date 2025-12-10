import json
import datetime
import utils
import logging

log = logging.getLogger(__name__)
utils.config_log()

class L4T_Calendar:
    """Contains functions used for the calendar app back-end"""

    entries_filepath = utils.create_path("storage", "entries.json")

    def __init__(self):
        # Load all calendar entries into a dictionary
        with open(self.entries_filepath, "r") as file:
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

        This version adjusts for an off-by-one issue in the curriculum:
        - For day 1: combines original day 1 and day 2 into a single entry.
        - For day d >= 2: uses the entry stored under day (d + 1), clamped
          to the last available day in that month.
        """
        try:
            month = str(int(date["month"]))  # normalize month key
            raw_day = date.get("day")
            day = int(raw_day) if raw_day else None

            month_entries = self.entries[month]

            # If only the theme is needed (no specific day)
            if day is None:
                return {"theme": month_entries["theme"]}

            # Determine how many days this month has in the JSON
            day_keys = [int(k) for k in month_entries.keys() if k != "theme"]
            if not day_keys:
                return {"theme": month_entries["theme"], "entry": ""}

            max_day = max(day_keys)

            # --- Special case: 1st of the month ---
            # Combine original day 1 + day 2 into a single entry.
            if day == 1:
                first = month_entries.get("1", "")
                second = month_entries.get("2", "")

                parts = []
                if first:
                    parts.append(first.strip())
                if second:
                    parts.append(second.strip())

                combined = "\n\n".join(p for p in parts if p)

                return {
                    "theme": month_entries["theme"],
                    "entry": combined,
                }

            # --- General case: shift everything else back by one day within the month ---
            # Visible day d -> stored entry at day (d + 1), but never past max_day.
            stored_day = day + 1
            if stored_day > max_day:
                stored_day = max_day

            stored_key = str(stored_day)
            entry_text = month_entries.get(stored_key, "")

            return {
                "theme": month_entries["theme"],
                "entry": entry_text,
            }

        except KeyError as err:
            log.critical(f"`get_entry` failed with input date={date}: {err}")
            return {"theme": "", "entry": ""}
        except Exception as err:
            log.critical(f"`get_entry` unexpected error with date={date}: {err}")
            return {"theme": "", "entry": ""}

    def modify_entry(self, date: dict[str, str], new_entry: str) -> None:
        """Modifies an entry in the `entries.json` file.

        `date`: dictionary containing the specified date. Format: `{'month': '6', 'day': '24'}`.
        `new_entry`: str containing the new entry.
        """
        month = str(int(date["month"]))
        day = str(int(date["day"])) if date["day"] else None

        # Edit entry in dict
        if day is None:
            self.entries[month]["theme"] = new_entry
        else:
            self.entries[month][day] = new_entry

        # Write to JSON file
        with open(self.entries_filepath, "w") as file:
            file.write(json.dumps(self.entries, indent=4))


if __name__ == "__main__":
    log = logging.getLogger(__name__)
    logging.basicConfig(filename=utils.create_log_path(__file__), level=logging.INFO)

