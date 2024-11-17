"File to send mobile and email notifications to users"

import json
import os

# from email.mime.text import MIMEText
# from email.mime.image import MIMEImage
# from email.mime.application import MIMEApplication
# from email.mime.multipart import MIMEMultipart
import smtplib
from L4T_calendar import L4T_Calendar
import logging
import utils

calendar = L4T_Calendar()

log = logging.getLogger(__name__)
utils.config_log()


def get_profiles():
    "Get user profiles from `data/profiles.json`"
    # Use an infinite loop so if the JSON is edited mid-function call, the function won't crash and will instead wait until the JSON is readable
    while True:
        try:
            with open(
                utils.create_path("storage", "profiles.json"),
                "r",
            ) as f:
                return json.load(f)
        except:
            continue


# TODO: add Lead4Tomorrow's account info here
username = "scoutingtmobile@gmail.com"
password = "bffo pepe ftcd fgyq"  # Needs to be the google "App Password", enable 2FA then make a new app password
CARRIERS = {
    "att": "@mms.att.net",
    "tmobile": "@tmomail.net",
    "verizon": "@vtext.com",
    "sprint": "@messaging.sprintpcs.com",
}


def send_email(to_email: str, subject: str, body: str) -> None:
    """Sends an email to the specified address.

    `to_email`: email address to send to

    `subject`: email subject

    `body`: email body
    """
    log.info(f"Sending email to {to_email}...")
    try:
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=120) as smtp:
            smtp.starttls()
            smtp.login(username, password)
            smtp.sendmail(username, to_email, f"Subject: {subject}\n\n{body}")
    except Exception as err:
        log.error(f"Email failed to send: {err}")
    log.info(f"Email sent to {to_email}")


def send_text(to_number: str, carrier: str, subject: str, body: str) -> None:
    """Sends a text to the specified phone number.

    `to_number`: mobile number to send to

    `carrier`: mobile carrier ("att", "tmobile", "verizon", "sprint")

    `subject`: text subject

    `body`: text content
    """
    log.info(f"Sending text to {to_number}...")

    try:
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=120) as smtp:
            smtp.starttls()
            smtp.login(username, password)
            smtp.sendmail(
                username,
                f"{to_number}{CARRIERS[carrier]}",
                f"Subject: {subject}\n\n\n{body}",
            )
    except Exception as err:
        log.error(f"Text failed to send: {err}")
    log.info(f"Text sent to {to_number}")


print("Starting notifications script...")

sent_days = {i: dict() for i in get_profiles().keys()}

# Loop forever and send notifications at the right time
while True:
    for i, profile in get_profiles().items():
        try:
            # Check if it's time to send the notification
            if (
                profile["time"]
                == calendar.get_curr_time(profile["timezone"]).strftime("%H:%M")
                and (today_short := calendar.get_today(profile["timezone"]))
                != sent_days[i]
            ):
                log.info(f"Sending {profile["method"]} notification to user {i}...")

                today_long = calendar.get_today(profile["timezone"], True)
                entry_dict = calendar.get_entry(today_short)

                subject = f"Lead4Tomorrow Calendar {today_short["month"]}/{today_short["day"]}"
                message = f"""We hope this message finds you well!

{today_long["month"]} is {entry_dict["theme"]}.

Today is {today_long["day"]}, {today_long["month"]} {today_short["day"]}. {entry_dict["entry"]}

Have a wonderful day,
Lead4Tomorrow
"""

                # Send email
                if profile["method"] == "email":
                    send_email(
                        profile["email"],
                        subject,
                        message,
                    )
                # Send text
                elif profile["method"] == "text":
                    send_text(profile["phone"], profile["carrier"], subject, message)

                # Update latest sent day
                sent_days[i] = today_short
                log.info(f"Sent {profile["method"]} notification to user {i}")
        # Loop cannot crash
        except Exception as err:
            log.critical(f"notifications.py main loop crashed: {err}")
            continue
