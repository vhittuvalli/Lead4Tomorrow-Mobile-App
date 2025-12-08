import json
import smtplib
import time
from L4T_calendar import L4T_Calendar
import logging
import requests
import os

from apns2.client import APNsClient
from apns2.payload import Payload
from apns2.credentials import TokenCredentials
from apns2.errors import Exception as APNsException

# ----------------------------
# Setup
# ----------------------------

calendar = L4T_Calendar()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

log.info("=== L4T NOTIFICATION SCRIPT (EMAIL + APNS PUSH) ===")

# Gmail credentials (app password only)
username = os.environ.get("GMAIL_USER1")
password = os.environ.get("GMAIL_PASS1")

if not username or not password:
    log.error("GMAIL_USER1 or GMAIL_PASS1 environment variables are not set! Email notifications will not work.")
else:
    log.info(f"Gmail username loaded: {username}")

# ----------------------------
# APNs setup (Token-based)
# ----------------------------

APNS_KEY_PATH = os.environ.get("APNS_KEY_PATH")   # path to .p8 file
APNS_KEY_ID = os.environ.get("APNS_KEY")          # you said you used APNS_KEY instead of APNS_KEY_ID
APNS_TEAM_ID = os.environ.get("APNS_TEAM_ID")
APNS_TOPIC = os.environ.get("APNS_TOPIC", "com.varunhittuvalli.Lead4Tomorrow-Calendar-App")

apns_client = None
if APNS_KEY_PATH and APNS_KEY_ID and APNS_TEAM_ID:
    try:
        creds = TokenCredentials(
            auth_key_path=APNS_KEY_PATH,
            key_id=APNS_KEY_ID,
            team_id=APNS_TEAM_ID
        )
        # use_sandbox=False for production; True if you're still on Apple dev sandbox
        apns_client = APNsClient(credentials=creds, use_sandbox=False)
        log.info("APNs client initialized successfully.")
    except Exception as e:
        log.error(f"Error initializing APNs client: {type(e).__name__}: {e}")
else:
    log.error("Missing one or more APNS_* environment variables; push notifications will not work.")


# ----------------------------
# Backend: get profiles
# ----------------------------

def get_profiles():
    try:
        log.debug("Fetching profiles from backend...")
        response = requests.get(
            "https://lead4tomorrow-mobile-app.onrender.com/show_profiles",
            timeout=10
        )
        response.raise_for_status()
        profiles = response.json()
        log.info(f"Fetched {len(profiles)} profiles from backend")
        return profiles
    except Exception as e:
        log.error(f"Error fetching profiles: {type(e).__name__}: {e}")
        return {}


# ----------------------------
# Email sending
# ----------------------------

def send_email(to_email, subject, body):
    if not username or not password:
        log.error("Cannot send email: missing Gmail credentials.")
        return

    log.info(f"Attempting to send email to {to_email} with subject '{subject}'")
    try:
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=60) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.ehlo()
            smtp.login(username, password)

            msg = (
                f"From: {username}\r\n"
                f"To: {to_email}\r\n"
                f"Subject: {subject}\r\n"
                f"\r\n"
                f"{body}"
            )

            smtp.sendmail(username, [to_email], msg)
        log.info(f"Email successfully sent to {to_email}")
    except smtplib.SMTPAuthenticationError as e:
        log.error(f"SMTP authentication failed: {e}")
    except smtplib.SMTPException as e:
        log.error(f"SMTP error while sending email to {to_email}: {type(e).__name__}: {e}")
    except Exception as e:
        log.error(f"Unexpected error sending email to {to_email}: {type(e).__name__}: {e}")


# ----------------------------
# Push (APNs) sending
# ----------------------------

def send_push(device_token, subject, body):
    if not apns_client:
        log.error("APNs client not initialized; cannot send push.")
        return

    if not device_token:
        log.error("No device_token provided; cannot send push.")
        return

    log.info(f"Sending APNs push to token starting {device_token[:10]}..., title='{subject}'")
    try:
        payload = Payload(alert={"title": subject, "body": body}, sound="default")

        # send_notification(token, payload, topic)
        apns_client.send_notification(device_token, payload, topic=APNS_TOPIC)
        log.info("APNs push notification SENT successfully.")
    except APNsException as e:
        log.error(f"APNs library exception: {type(e).__name__}: {e}")
    except Exception as e:
        log.error(f"Unexpected error during APNs send: {type(e).__name__}: {e}")


# ----------------------------
# Main loop setup
# ----------------------------

profiles_initial = get_profiles()
sent_days = {email: None for email in profiles_initial.keys()}
log.info(f"Initialized sent_days for {len(sent_days)} emails")


# ----------------------------
# Main notification loop
# ----------------------------

while True:
    profiles = get_profiles()

    for email, profile in profiles.items():
        try:
            # --- SAFE TIMEZONE HANDLING ---
            tz_raw = profile.get("timezone")
            if tz_raw in (None, ""):
                offset = 0
            else:
                try:
                    offset = int(tz_raw)
                except (ValueError, TypeError):
                    log.warning(f"Invalid timezone '{tz_raw}' for {email}, defaulting to 0")
                    offset = 0

            current_time = calendar.get_curr_time(offset).strftime("%H:%M")
            today_short = calendar.get_today(offset)
            today_long = calendar.get_today(offset, True)

            log.debug(
                f"Profile {email}: method={profile.get('method')}, "
                f"target_time={profile.get('time')}, "
                f"current_time={current_time}, "
                f"last_sent={sent_days.get(email)}, "
                f"today_short={today_short}"
            )

            # Main condition for sending
            if (
                profile.get("time") == current_time
                and today_short != sent_days.get(email)
            ):
                entry = calendar.get_entry(today_short)
                subject = f"Lead4Tomorrow Calendar {today_short['month']}/{today_short['day']}"
                message = f"""We hope this message finds you well!

{today_long["month"]} is {entry["theme"]}.
Today is {today_long["day"]}, {today_long["month"]} {today_short["day"]}. {entry["entry"]}

Have a wonderful day,
Lead4Tomorrow
"""

                method = (profile.get("method") or "").lower()
                log.info(f"Triggering notification for {email} via {method}")

                if method == "email":
                    send_email(email, subject, message)
                elif method == "push":
                    device_token = profile.get("device_token")
                    if not device_token:
                        log.error(f"No device_token for profile {email}, cannot send push.")
                    else:
                        send_push(device_token, subject, message)
                else:
                    log.error(f"Unknown notification method '{profile.get('method')}' for {email}")

                sent_days[email] = today_short
                log.info(f"Marked {email} as sent for {today_short}")

        except Exception as e:
            log.error(f"Error processing profile {email}: {type(e).__name__}: {e}")

    time.sleep(60)

