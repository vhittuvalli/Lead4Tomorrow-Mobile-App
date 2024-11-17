import json
import datetime
import utils
import logging

log = logging.getLogger(__name__)
utils.config_log()


class L4T_Calendar:
    "Contains functions used for the calendar app back-end"

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
        """Returns the current month and day in a dictionary format; e.g. `{'month': '1', 'day': '1'}`

        `timezone`: hour difference from UTC. For example, Pacific Standard Time would be `-8`.

        `long_form`: if `True`, returns the name of the month and day, e.g. `{"month": "January", "day": "Monday"}`
        """
        today = self.get_curr_time(timezone)

        if not long_form:
            return {"month": today.strftime("%m"), "day": today.strftime("%d")}
        else:
            return {"month": today.strftime("%B"), "day": today.strftime("%A")}

    def get_entry(self, date) -> dict:
        """Returns the entry for a given day with the theme of the month.

        `date`: dictionary containing the specified date. The format should be `{'month': '6', 'day': '24'}`.

        If `day` is `None` but `month` is specified, returns that month's theme.
        """
        try:
            if date["day"] is None:
                return {"theme": self.entries[date["month"]]["theme"]}
            else:
                return {
                    "theme": self.entries[date["month"]]["theme"],
                    "entry": self.entries[date["month"]][date["day"]],
                }
        except Exception as err:
            log.critical(f"`get_entry` failed with input {date=}: {err}")
            return {"theme": "", "entry": ""}

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


if __name__ == "__main__":
    log = logging.getLogger(__name__)
    logging.basicConfig(filename=utils.create_log_path(__file__), level=logging.INFO)
