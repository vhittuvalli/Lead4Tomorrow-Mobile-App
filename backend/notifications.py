"File to send mobile and email notifications to users"

import json
import os

# from email.mime.text import MIMEText
# from email.mime.image import MIMEImage
# from email.mime.application import MIMEApplication
# from email.mime.multipart import MIMEMultipart
import smtplib
from L4T_calendar import L4T_Calendar

calendar = L4T_Calendar()


def get_profiles():
    "Get user profiles from `data/profiles.json`"
    # Use an infinite loop so if the JSON is edited mid-function call, the function won't crash and will instead wait until the JSON is readable
    while True:
        try:
            with open(
                os.path.abspath(
                    os.path.join(
                        os.path.dirname(__file__), "..", "data", "profiles.json"
                    )
                ),
                "r",
            ) as f:
                return json.load(f)
        except:
            continue


# TODO: add Lead4Tomorrow's account info here
username = "scoutingtmobile@gmail.com"
password = "bffo pepe ftcd fgyq"  # Needs to be the google "App Password", enable 2FA then make a new app password


def send_email(to_email: str, subject: str, body: str) -> None:
    """Sends an email to the specified address.

    `to_email`: email address to send to

    `subject`: email subject

    `body`: email body
    """
    print(f"Sending email to {to_email}...")
    try:
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=120) as smtp:
            smtp.starttls()
            smtp.login(username, password)
            smtp.sendmail(username, to_email, f"Subject: {subject}\n\n{body}")
    except Exception as err:
        print(f"Email failed to send: {err}")
    print(f"Email sent to {to_email}")


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
                print(f"Sending {profile["method"]} notification to user {i}...")

                today_long = calendar.get_today(profile["timezone"], True)
                entry_dict = calendar.get_entry(today_short)

                message = f"""We hope this email finds you well!

{today_long["month"]} is {entry_dict["theme"]}.

Today is {today_long["day"]}, {today_long["month"]} {today_short["day"]}. {entry_dict["entry"]}

Have a wonderful day,
Lead4Tomorrow
"""

                # Send email
                if profile["method"] == "email":
                    send_email(
                        profile["email"],
                        f"Lead4Tomorrow Calendar {today_short["month"]}/{today_short["day"]}",
                        message,
                    )

                    # Update latest sent day
                    sent_days[i] = today_short
                # Send text
                elif profile["method"] == "text":
                    continue

                print(f"Sent {profile["method"]} notification to user {i}")
        # Loop cannot crash
        except Exception as err:
            # TODO: add log somewhere
            print(f"Error: {err}")
            continue
