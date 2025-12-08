import json
import smtplib
import time
from L4T_calendar import L4T_Calendar
import logging
import requests
import os

import collections
import collections.abc

# ------------------------------------------------------------------
# Temporary compatibility patch for Python 3.13 + 'hyper' dependency
# ------------------------------------------------------------------
if not hasattr(collections, "Iterable"):
    collections.Iterable = collections.abc.Iterable
if not hasattr(collections, "Mapping"):
    collections.Mapping = collections.abc.Mapping
if not hasattr(collections, "MutableMapping"):
    collections.MutableMapping = collections.abc.MutableMapping
if not hasattr(collections, "MutableSet"):
    collections.MutableSet = collections.abc.MutableSet
if not hasattr(collections, "Callable"):
    collections.Callable = collections.abc.Callable

import ssl
if not hasattr(ssl, 'verify_hostname'):
    ssl.verify_hostname = lambda cert, hostname: None

# APNS imports
from apns2.client import APNsClient
from apns2.credentials import TokenCredentials
from apns2.payload import Payload
from apns2.errors import (
    BadDeviceToken,
    Unregistered,
    PayloadTooLarge,
    TooManyRequests,
    ServiceUnavailable,
    InternalServerError,
)


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

APNS_KEY_PATH = os.environ.get("APNS_KEY")   # path to .p8 file
APNS_KEY_ID = os.environ.get("APNS_KEY_ID")          # your key ID env var
APNS_TEAM_ID = os.environ.get("APNS_TEAM_ID")
APNS_TOPIC = os.environ.get("APNS_BUNDLE_ID")
log.info(f"APNS_KEY_PATH: {APNS_KEY_PATH}")
log.info(f"APNS_KEY_ID: {APNS_KEY_ID}")
log.info(f"APNS_TEAM_ID: {APNS_TEAM_ID}")
log.info(f"APNS_TOPIC: {APNS_TOPIC}")

apns_client = None
if APNS_KEY_PATH and APNS_KEY_ID and APNS_TEAM_ID:
    try:
        creds = TokenCredentials(
            auth_key_path=APNS_KEY_PATH,
            auth_key_id=APNS_KEY_ID,
            team_id=APNS_TEAM_ID
        )

        apns_client = APNsClient(
            credentials=creds,
            use_sandbox=False,   # set True only if you are using iOS dev builds
            use_alternative_port=False
        )

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

    try:
        with smtplib.SMTP("smtp.gmail.com", 587, timeout=60) as smtp:
            smtp.starttls()
            smtp.login(username, password)

            msg = (
                f"From: {username}\r\n"
                f"To: {to_email}\r\n"
                f"Subject: {subject}\r\n\r\n"
                f"{body}"
            )

            smtp.sendmail(username, [to_email], msg)

        log.info(f"Email sent to {to_email}")

    except Exception as e:
        log.error(f"Email error for {to_email}: {type(e).__name__}: {e}")

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

    try:
        payload = Payload(alert={"title": subject, "body": body}, sound="default")

        apns_client.send_notification(
            device_token,
            payload,
            topic=APNS_TOPIC
        )

        log.info(f"APNs push sent to {device_token[:8]}...")

    except BadDeviceToken:
        log.error(f"BadDeviceToken for token {device_token}")
    except Unregistered:
        log.error(f"Unregistered device {device_token}")
    except PayloadTooLarge:
        log.error("PayloadTooLarge error")
    except TooManyRequests:
        log.error("TooManyRequests (APNs rate limited)")
    except ServiceUnavailable:
        log.error("ServiceUnavailable (APNs down)")
    except InternalServerError:
        log.error("InternalServerError from APNs")
    except Exception as e:
        log.error(f"Unexpected APNs error: {type(e).__name__}: {e}")

# ----------------------------
# Main loop
# ----------------------------

profiles_initial = get_profiles()
sent_days = {email: None for email in profiles_initial.keys()}

log.info(f"Initialized sent_days for {len(sent_days)} users")

while True:
    profiles = get_profiles()

    for email, profile in profiles.items():
        try:
            # Timezone handling
            tz_raw = profile.get("timezone")
            try:
                offset = int(tz_raw) if tz_raw else 0
            except Exception:
                offset = 0

            current_time = calendar.get_curr_time(offset).strftime("%H:%M")
            today_short = calendar.get_today(offset)
            today_long = calendar.get_today(offset, True)

            # Should this profile get a message?
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

                if method == "email":
                    send_email(email, subject, message)
                elif method == "push":
                    device_token = profile.get("device_token")
                    send_push(device_token, subject, message)
                else:
                    log.error(f"Unknown method '{method}' for {email}")

                sent_days[email] = today_short

        except Exception as e:
            log.error(f"Error in notification loop for {email}: {type(e).__name__}: {e}")

    time.sleep(60)
