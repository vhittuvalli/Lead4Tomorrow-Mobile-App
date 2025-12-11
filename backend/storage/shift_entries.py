import json

INPUT_PATH = "entries.json"   # path to your current JSON
OUTPUT_PATH = "entries_shifted.json"   # where to write the updated JSON

def shift_month(month_dict):
    # Keep theme as-is
    theme = month_dict.get("theme", "")
    # Collect numeric day keys only
    day_keys = sorted(
        [int(k) for k in month_dict.keys() if k != "theme"]
    )
    if len(day_keys) < 2:
        # Nothing to shift / merge
        return month_dict

    last_day = max(day_keys)

    new_month = {"theme": theme}

    # 1) New day 1 = old day1 + old day2
    d1 = month_dict[str(day_keys[0])]
    d2 = month_dict[str(day_keys[1])]
    new_month["1"] = d1.rstrip() + " " + d2.lstrip()

    # 2) For days 2..last-1, shift back by one (new d = old d+1)
    for d in range(2, last_day):
        new_month[str(d)] = month_dict[str(d + 1)]

    # 3) For the last day, just duplicate the old last day
    new_month[str(last_day)] = month_dict[str(last_day)]

    return new_month


def main():
    with open(INPUT_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    updated = {}
    for month, month_dict in data.items():
        # Only touch the month objects; keep the same keys ("1".."12")
        updated[month] = shift_month(month_dict)

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(updated, f, indent=4, ensure_ascii=False)

    print(f"Wrote shifted calendar to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
