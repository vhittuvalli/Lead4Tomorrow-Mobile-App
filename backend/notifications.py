import json
import smtplib
import time
from L4T_calendar import L4T_Calendar
import logging
import requests
import os

# Initialize calendar and logging
calendar = L4T_Calendar()
log = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# Gmail credentials (app password only)
username = os.environ.get("GMAIL_USER")
password = os.environ.get("GMAIL_PASS")
 
# Carrier gateways for SMS
CARRIERS = {
    "att": "@mms.att.net",
    "tmobile": "@tmomail.net",
    "verizon": "@vtext.com",
    "sprint": "@messaging.sprintpcs.com",
}

# Fetch profiles from live backend
def get_profiles():
    try:
        response = requests.get("https://lead4tomorrow-mobile-app.onrender.com/show_profiles", timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        log.error(f"Error fetching profiles: {e}")
        return {}

# Send email
def send_email(to_email, subject, body):
    try:
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=60) as smtp:
            smtp.starttls()
            smtp.login(username, password)
            smtp.sendmail(username, to_email, f"Subject: {subject}\n\n{body}")
        log.info(f"Email sent to {to_email}")
    except Exception as e:
        log.error(f"Failed to send email to {to_email}: {e}")

# Send text via email-to-SMS
def send_text(phone, carrier, subject, body):
    to_address = f"{phone}{CARRIERS.get(carrier, '')}"
    send_email(to_address, subject, body)

# Start notifications loop
print("Starting notification loop...")
sent_days = {email: None for email in get_profiles().keys()}

while True:
    profiles = get_profiles()
    for email, profile in profiles.items():
        try:
            offset = int(profile.get("timezone", "0"))
            current_time = calendar.get_curr_time(offset).strftime("%H:%M")
            today_short = calendar.get_today(offset)
            today_long = calendar.get_today(offset, True)

            if profile["time"] == current_time and today_short != sent_days.get(email):
                entry = calendar.get_entry(today_short)
                subject = f"Lead4Tomorrow Calendar {today_short['month']}/{today_short['day']}"
                message = f"""We hope this message finds you well!

{today_long["month"]} is {entry["theme"]}.
Today is {today_long["day"]}, {today_long["month"]} {today_short["day"]}. {entry["entry"]}

Have a wonderful day,
Lead4Tomorrow
"""
                if profile["method"] == "email":
                    send_email(email, subject, message)
                elif profile["method"] == "text":
                    send_text(profile["phone"], profile["carrier"], subject, message)

                sent_days[email] = today_short
                log.info(f"Sent {profile['method']} notification to {email}")

        except Exception as e:
            log.error(f"Error processing profile {email}: {e}")
    time.sleep(60)

