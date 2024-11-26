import json
import os
import smtplib
from L4T_calendar import L4T_Calendar
import logging
import utils

calendar = L4T_Calendar()

log = logging.getLogger(__name__)
utils.config_log()

def get_profiles():
    """Get user profiles from `storage/profiles.json`."""
    while True:
        try:
            with open(utils.create_path("storage", "profiles.json"), "r") as f:
                profiles = json.load(f)
                log.debug(f"Loaded profiles: {profiles}")
                return profiles
        except Exception as e:
            log.error(f"Failed to load profiles.json: {e}")
            return {}

# TODO: Add Lead4Tomorrow's account info here
username = "scoutingtmobile@gmail.com"
password = "bffo pepe ftcd fgyq"  # Needs to be the Google "App Password"
CARRIERS = {
    "att": "@mms.att.net",
    "tmobile": "@tmomail.net",
    "verizon": "@vtext.com",
    "sprint": "@messaging.sprintpcs.com",
}

def send_email(to_email: str, subject: str, body: str) -> None:
    """Send an email to the specified address."""
    log.info(f"Sending email to {to_email}...")
    try:
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=120) as smtp:
            smtp.starttls()
            smtp.login(username, password)
            smtp.sendmail(username, to_email, f"Subject: {subject}\n\n{body}")
        log.info(f"Email sent to {to_email}")
    except Exception as err:
        log.error(f"Email failed to send: {err}")

def send_text(to_number: str, carrier: str, subject: str, body: str) -> None:
    """Send a text to the specified phone number."""
    log.info(f"Sending text to {to_number}...")
    try:
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=120) as smtp:
            smtp.starttls()
            smtp.login(username, password)
            smtp.sendmail(
                username,
                f"{to_number}{CARRIERS[carrier]}",
                f"Subject: {subject}\n\n{body}",
            )
        log.info(f"Text sent to {to_number}")
    except Exception as err:
        log.error(f"Text failed to send: {err}")

print("Starting notifications script...")

# Initialize sent days to track notifications
sent_days = {i: None for i in get_profiles().keys()}

# Main notification loop
while True:
    profiles = get_profiles()
    log.debug(f"Loaded profiles: {profiles}")

    for i, profile in profiles.items():
        try:
            log.debug(f"Processing profile {i}: {profile}")

            # Get the current time and today's date
            current_time = calendar.get_curr_time(profile["timezone"]).strftime("%H:%M")
            today_short = calendar.get_today(profile["timezone"])
            log.debug(f"Current time: {current_time}, Notification time: {profile['time']}")
            log.debug(f"Today's date: {today_short}, Last sent: {sent_days.get(i)}")

            # Check if it's time to send the notification
            if profile["time"] == current_time and today_short != sent_days[i]:
                log.info(f"Sending {profile['method']} notification to user {i}...")

                today_long = calendar.get_today(profile["timezone"], True)
                entry_dict = calendar.get_entry(today_short)
                log.debug(f"Entry for today: {entry_dict}")

                subject = f"Lead4Tomorrow Calendar {today_short['month']}/{today_short['day']}"
                message = f"""We hope this message finds you well!

{today_long["month"]} is {entry_dict["theme"]}.

Today is {today_long["day"]}, {today_long["month"]} {today_short["day"]}. {entry_dict["entry"]}

Have a wonderful day,
Lead4Tomorrow
"""

                # Send email or text
                if profile["method"] == "email":
                    send_email(profile["email"], subject, message)
                elif profile["method"] == "text":
                    send_text(profile["phone"], profile["carrier"], subject, message)

                # Update the sent day
                sent_days[i] = today_short
                log.info(f"Sent {profile['method']} notification to user {i}")

        except Exception as err:
            log.critical(f"Error processing profile {i}: {err}")
            continue
