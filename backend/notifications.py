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
    level=logging.DEBUG,  # Changed to DEBUG for more detailed logs
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

APNS_KEY_PATH = os.environ.get("APNS_KEY")
APNS_KEY_ID = os.environ.get("APNS_KEY_ID")
APNS_TEAM_ID = os.environ.get("APNS_TEAM_ID")
APNS_TOPIC = os.environ.get("APNS_BUNDLE_ID")
APNS_USE_SANDBOX = os.environ.get("APNS_USE_SANDBOX", "false").lower() == "true"

log.info(f"APNS_KEY_PATH: {APNS_KEY_PATH}")
log.info(f"APNS_KEY_ID: {APNS_KEY_ID}")
log.info(f"APNS_TEAM_ID: {APNS_TEAM_ID}")
log.info(f"APNS_TOPIC: {APNS_TOPIC}")
log.info(f"APNS_USE_SANDBOX: {APNS_USE_SANDBOX}")

apns_client = None
if APNS_KEY_PATH and APNS_KEY_ID and APNS_TEAM_ID:
    try:
        log.info("Attempting to initialize APNs client...")
        creds = TokenCredentials(
            auth_key_path=APNS_KEY_PATH,
            auth_key_id=APNS_KEY_ID,
            team_id=APNS_TEAM_ID
        )
        log.debug("TokenCredentials created successfully")

        apns_client = APNsClient(
            credentials=creds,
            use_sandbox=APNS_USE_SANDBOX,
            use_alternative_port=False
        )

        log.info(f"APNs client initialized successfully (sandbox={APNS_USE_SANDBOX})")
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
        log.debug(f"Profile emails: {list(profiles.keys())}")
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
        log.info(f"Sending email to {to_email}...")
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

        log.info(f"✓ Email sent successfully to {to_email}")

    except Exception as e:
        log.error(f"✗ Email error for {to_email}: {type(e).__name__}: {e}")

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
        log.info(f"=" * 60)
        log.info(f"📱 PREPARING PUSH NOTIFICATION")
        log.info(f"=" * 60)
        log.info(f"Target device: {device_token[:8]}...{device_token[-8:]}")
        log.info(f"Full device token: {device_token}")
        log.info(f"-" * 60)
        log.info(f"NOTIFICATION TITLE:")
        log.info(f"  {subject}")
        log.info(f"-" * 60)
        log.info(f"NOTIFICATION BODY ({len(body)} characters):")
        log.info(f"{body}")
        log.info(f"-" * 60)
        log.info(f"APNs Topic: {APNS_TOPIC}")
        log.info(f"Sandbox Mode: {APNS_USE_SANDBOX}")
        log.info(f"=" * 60)
        
        # Create rich notification that's clickable and persistent
        payload = Payload(
            alert={
                "title": subject,
                "body": body,
                "sound": "default"
            },
            badge=1,
            sound="default",
            content_available=True,  # Allows app to process in background
            mutable_content=True,     # Allows notification to be modified
            category="CALENDAR_NOTIFICATION"  # Custom category for handling
        )
        
        log.info("📤 Payload created, sending to APNs...")

        apns_client.send_notification(
            device_token,
            payload,
            topic=APNS_TOPIC
        )

        log.info(f"=" * 60)
        log.info(f"✅ PUSH NOTIFICATION SENT SUCCESSFULLY!")
        log.info(f"=" * 60)
        log.info(f"Device: {device_token[:8]}...{device_token[-8:]}")
        log.info(f"The notification should now:")
        log.info(f"  ✓ Appear as a banner on the device")
        log.info(f"  ✓ Play a sound")
        log.info(f"  ✓ Show a badge on the app icon")
        log.info(f"  ✓ Be stored in Notification Center history")
        log.info(f"  ✓ Be clickable to open the app")
        log.info(f"=" * 60)

    except BadDeviceToken:
        log.error(f"=" * 60)
        log.error(f"✗ PUSH NOTIFICATION FAILED: BadDeviceToken")
        log.error(f"=" * 60)
        log.error(f"Device token {device_token[:8]}...{device_token[-8:]} is invalid")
        log.error(f"This usually means:")
        log.error(f"  - Token is from wrong environment (sandbox vs production)")
        log.error(f"  - App was uninstalled and reinstalled")
        log.error(f"  - Token format is incorrect")
        log.error(f"=" * 60)
    except Unregistered:
        log.error(f"=" * 60)
        log.error(f"✗ PUSH NOTIFICATION FAILED: Unregistered")
        log.error(f"=" * 60)
        log.error(f"Device {device_token[:8]}...{device_token[-8:]} is no longer registered")
        log.error(f"This usually means the app was uninstalled")
        log.error(f"=" * 60)
    except PayloadTooLarge:
        log.error(f"=" * 60)
        log.error(f"✗ PUSH NOTIFICATION FAILED: PayloadTooLarge")
        log.error(f"=" * 60)
        log.error(f"The notification content is too large (max 4KB)")
        log.error(f"Current body length: {len(body)} characters")
        log.error(f"=" * 60)
    except TooManyRequests:
        log.error(f"=" * 60)
        log.error(f"✗ PUSH NOTIFICATION FAILED: TooManyRequests")
        log.error(f"=" * 60)
        log.error(f"APNs rate limit exceeded - too many notifications sent too quickly")
        log.error(f"=" * 60)
    except ServiceUnavailable:
        log.error(f"=" * 60)
        log.error(f"✗ PUSH NOTIFICATION FAILED: ServiceUnavailable")
        log.error(f"=" * 60)
        log.error(f"Apple's APNs servers are temporarily down")
        log.error(f"Will retry on next loop iteration")
        log.error(f"=" * 60)
    except InternalServerError:
        log.error(f"=" * 60)
        log.error(f"✗ PUSH NOTIFICATION FAILED: InternalServerError")
        log.error(f"=" * 60)
        log.error(f"APNs internal server error - this is on Apple's side")
        log.error(f"=" * 60)
    except Exception as e:
        log.error(f"=" * 60)
        log.error(f"✗ PUSH NOTIFICATION FAILED: Unexpected Error")
        log.error(f"=" * 60)
        log.error(f"Error type: {type(e).__name__}")
        log.error(f"Error message: {e}")
        log.error(f"Full device token: {device_token}")
        log.error(f"=" * 60)
        import traceback
        log.error(traceback.format_exc())

# ----------------------------
# Main loop
# ----------------------------

profiles_initial = get_profiles()
sent_days = {email: None for email in profiles_initial.keys()}

log.info(f"Initialized sent_days for {len(sent_days)} users")
log.debug(f"Initial sent_days: {sent_days}")

loop_count = 0

while True:
    loop_count += 1
    log.debug(f"--- Loop iteration {loop_count} ---")
    
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
            
            user_time = profile.get("time")
            method = (profile.get("method") or "").lower()
            
            log.debug(f"Checking {email}: method={method}, user_time={user_time}, current_time={current_time}, offset={offset}")
            
            # Check if already sent today
            if email in sent_days and sent_days[email] == today_short:
                log.debug(f"  → Already sent today for {email}, skipping")
                continue
            
            # Check if it's time to send
            if user_time != current_time:
                log.debug(f"  → Time mismatch for {email}: {user_time} != {current_time}")
                continue
            
            # Time matches and not sent today!
            log.info(f"")
            log.info(f"🎯" + "=" * 58 + "🎯")
            log.info(f"⏰ TIME MATCH DETECTED!")
            log.info(f"=" * 60)
            log.info(f"User: {email}")
            log.info(f"Method: {method.upper()}")
            log.info(f"Current time: {current_time}")
            log.info(f"User's scheduled time: {user_time}")
            log.info(f"Date: {today_long['day']}, {today_long['month']} {today_short['day']}")
            log.info(f"Timezone offset: {offset}")
            log.info(f"=" * 60)
            
            entry = calendar.get_entry(today_short)
            log.info(f"📖 Calendar Entry Retrieved:")
            log.info(f"  Theme: {entry['theme']}")
            log.info(f"  Entry length: {len(entry['entry'])} characters")

            subject = f"Lead4Tomorrow Calendar {today_short['month']}/{today_short['day']}"
            message = f"""We hope this message finds you well!

{today_long["month"]} is {entry["theme"]}.
Today is {today_long["day"]}, {today_long["month"]} {today_short["day"]}. {entry["entry"]}

Have a wonderful day,
Lead4Tomorrow
"""

            log.info(f"")
            log.info(f"📧 DELIVERY METHOD: {method.upper()}")
            log.info(f"=" * 60)

            if method == "email":
                log.info(f"Sending EMAIL notification...")
                send_email(email, subject, message)
            elif method == "push":
                device_token = profile.get("device_token")
                if device_token:
                    log.info(f"Sending PUSH notification...")
                    log.debug(f"Device token (partial): {device_token[:16]}...{device_token[-16:]}")
                    send_push(device_token, subject, message)
                else:
                    log.error(f"=" * 60)
                    log.error(f"✗ CANNOT SEND PUSH: No device token found")
                    log.error(f"=" * 60)
                    log.error(f"User: {email}")
                    log.error(f"Profile data: {profile}")
                    log.error(f"The user may need to re-enable push notifications in the app")
                    log.error(f"=" * 60)
            else:
                log.error(f"=" * 60)
                log.error(f"✗ UNKNOWN NOTIFICATION METHOD")
                log.error(f"=" * 60)
                log.error(f"User: {email}")
                log.error(f"Method received: '{method}'")
                log.error(f"Valid methods are: 'email' or 'push'")
                log.error(f"=" * 60)

            # Mark as sent
            sent_days[email] = today_short
            log.info(f"")
            log.info(f"✅ NOTIFICATION COMPLETE")
            log.info(f"=" * 60)
            log.info(f"User {email} marked as sent for {today_short['month']}/{today_short['day']}")
            log.info(f"This user will not receive another notification until tomorrow")
            log.info(f"=" * 60)
            log.info(f"")

        except Exception as e:
            log.error(f"✗ Error in notification loop for {email}: {type(e).__name__}: {e}")

    log.debug(f"Sleeping for 60 seconds... (Loop {loop_count} complete)")
    time.sleep(60)
