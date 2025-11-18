import json
import smtplib
import time
from L4T_calendar import L4T_Calendar
import logging
import requests
import os

# ----------------------------
# Setup
# ----------------------------

calendar = L4T_Calendar()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

log.info("=== L4T NOTIFICATION SCRIPT VERSION 2.1 (SAFE TZ + PUSHOVER DEBUG) ===")

# TEMP: hard-coded Pushover credentials for DEBUG ONLY
# TODO: rotate these and move into environment variables after testing
PUSHOVER_APP_TOKEN = "a3r7qn9z2ogz9wsmm8n1zcatzsntnc"
PUSHOVER_TEST_USER_KEY = "uez5osu9q7yoja32sf2cnu91fdpypw"

# Gmail credentials (app password only)
username = os.environ.get("GMAIL_USER1")
password = os.environ.get("GMAIL_PASS1")

if not username or not password:
    log.error("GMAIL_USER1 or GMAIL_PASS1 environment variables are not set! Email notifications will not work.")
else:
    log.info(f"Gmail username loaded: {username}")


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
# Text (Pushover) sending
# ----------------------------

def send_text(user_key, subject, body):
    """
    TEMP DEBUG VERSION — uses hard-coded Pushover keys.
    Once confirmed working, swap back to environment variables.
    """
    pushover_token = PUSHOVER_APP_TOKEN

    # If you want to ignore profile user_key for now and always send to you:
    if not user_key:
        log.warning("Profile has no user_key; using PUSHOVER_TEST_USER_KEY instead.")
        user_key = PUSHOVER_TEST_USER_KEY

    log.info(
        f"[DEBUG] Pushover send -> TOKEN starts: {pushover_token[:6]}..., "
        f"USER_KEY starts: {user_key[:6]}..., title='{subject}'"
    )

    if not pushover_token:
        log.error("[DEBUG] Missing pushover_token — not sending.")
        return
    if not user_key:
        log.error("[DEBUG] Missing user_key — not sending.")
        return

    try:
        resp = requests.post(
            "https://api.pushover.net/1/messages.json",
            data={
                "token": pushover_token,
                "user": user_key,
                "title": subject,
                "message": body,
            },
            timeout=10
        )

        if resp.status_code == 200:
            log.info("[DEBUG] Pushover notification SENT successfully.")
        else:
            log.error(f"[DEBUG] Pushover ERROR {resp.status_code}: {resp.text}")

    except Exception as e:
        log.error(f"[DEBUG] Exception during Pushover send: {type(e).__name__}: {e}")


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
                elif method in ("text", "sms"):
                    # Using 'phone' as pushover user key for now; can switch to 'pushover_user_key' later
                    user_key = profile.get("phone") or profile.get("pushover_user_key")
                    send_text(user_key, subject, message)
                else:
                    log.error(f"Unknown notification method '{profile.get('method')}' for {email}")

                sent_days[email] = today_short
                log.info(f"Marked {email} as sent for {today_short}")

        except Exception as e:
            log.error(f"Error processing profile {email}: {type(e).__name__}: {e}")

    time.sleep(60)

