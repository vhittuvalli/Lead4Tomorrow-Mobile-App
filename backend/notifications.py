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

# ----------------------------
# Setup
# ----------------------------

calendar = L4T_Calendar()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

log.info("=== L4T NOTIFICATION SCRIPT VERSION 3.0 (EMAIL + APNS PUSH) ===")

# Gmail credentials (app password only)
username = os.environ.get("GMAIL_USER1")
password = os.environ.get("GMAIL_PASS1")

if not username or not password:
    log.error("GMAIL_USER1 or GMAIL_PASS1 environment variables are not set! Email notifications will not work.")
else:
    log.info(f"Gmail username loaded: {username}")

# APNs (Apple Push Notification) credentials from environment
APNS_AUTH_KEY_PATH = os.environ.get("APNS_AUTH_KEY_PATH")  # e.g. /etc/secrets/AuthKey_XXXXXXX.p8
APNS_TEAM_ID = os.environ.get("APNS_TEAM_ID")              # Your Apple Developer Team ID
APNS_KEY_ID = os.environ.get("APNS_KEY")                   # The Key ID you created for APNs
APNS_BUNDLE_ID = os.environ.get("APNS_BUNDLE_ID")          # e.g. com.varunhittuvalli.Lead4Tomorrow-Calendar-App

apns_client = None  # lazy init


def init_apns_client():
    """
    Lazily initialize the global APNs client using token-based auth.
    """
    global apns_client

    if apns_client is not None:
        return apns_client

    missing = []
    if not APNS_AUTH_KEY_PATH:
        missing.append("APNS_AUTH_KEY_PATH")
    if not APNS_TEAM_ID:
        missing.append("APNS_TEAM_ID")
    if not APNS_KEY_ID:
        missing.append("APNS_KEY (Key ID)")
    if not APNS_BUNDLE_ID:
        missing.append("APNS_BUNDLE_ID")

    if missing:
        log.error(f"Cannot initialize APNs client. Missing env vars: {', '.join(missing)}")
        return None

    try:
        credentials = TokenCredentials(
            auth_key_path=APNS_AUTH_KEY_PATH,
            team_id=APNS_TEAM_ID,
            key_id=APNS_KEY_ID,
        )
        # use_sandbox=False for production
        apns_client = APNsClient(
            credentials=credentials,
            use_sandbox=False,
            use_alternative_port=False,
        )
        log.info("APNs client initialized successfully.")
    except Exception as e:
        log.error(f"Failed to initialize APNs client: {type(e).__name__}: {e}")
        apns_client = None

    return apns_client


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
# Push notification sending (APNs)
# ----------------------------

def send_push(device_token, title, body):
    """
    Send an APNs push notification to a single device token.

    device_token: hex string device token from iOS app
    title: notification title
    body: notification body
    """
    if not device_token:
        log.error("No device_token provided for push notification.")
        return

    client = init_apns_client()
    if client is None:
        log.error("APNs client not initialized; cannot send push.")
        return

    try:
        payload = Payload(
            alert={"title": title, "body": body},
            sound="default",
            badge=1
        )

        log.info(f"Sending APNs push to token starting with {device_token[:10]}...")
        client.send_notification(
            token=device_token,
            notification=payload,
            topic=APNS_BUNDLE_ID,
            push_type="alert"
        )
        log.info("APNs push sent successfully.")
    except Exception as e:
        log.error(f"Error sending APNs push: {type(e).__name__}: {e}")


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
            # --- SAFE TIMEZONE HANDLING (no more int(None)) ---
            tz_raw = profile.get("timezone")
            if tz_raw in (None, ""):
                offset = 0
            else:
                try:
                    offset = int(tz_raw)
                except ValueError:
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
                elif method in ("push", "text", "sms"):
                    # Expecting profile["device_token"] to contain the APNs device token
                    device_token = profile.get("device_token")
                    if not device_token:
                        log.error(f"No device_token for profile {email}, cannot send push.")
                    else:
                        send_push(device_token, subject, entry["entry"])
                else:
                    log.error(f"Unknown notification method '{profile.get('method')}' for {email}")

                sent_days[email] = today_short
                log.info(f"Marked {email} as sent for {today_short}")

        except Exception as e:
            log.error(f"Error processing profile {email}: {type(e).__name__}: {e}")

    time.sleep(60)

