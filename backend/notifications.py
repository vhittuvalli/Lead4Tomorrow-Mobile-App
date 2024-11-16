"File to send mobile and email notifications to users"

import datetime
import json
import os

# from email.mime.text import MIMEText
# from email.mime.image import MIMEImage
# from email.mime.application import MIMEApplication
# from email.mime.multipart import MIMEMultipart
import smtplib
from L4T_calendar import L4T_Calendar

calendar = L4T_Calendar()

with open(
    os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "data", "profiles.json")
    ),
    "r",
) as f:
    profiles = json.load(f)

# TODO: add server to auto-end emails, iterate through `profiles` and send emails to each profile at its specified time

# TODO: add Lead4Tomorrow's account info here
username = "scoutingtmobile@gmail.com"
password = "bffo pepe ftcd fgyq"  # Needs to be the google "App Password", enable 2FA then make a new app password


# TODO: test newline printing in email body
def send_email(to_email: str, subject: str, body: str) -> None:
    """Sends an email to the specified address.

    `to_email`: email address to send to

    `subject`: email subject

    `body`: email body
    """
    print("Sending email...")
    with smtplib.SMTP("smtp.gmail.com", 587, timeout=120) as smtp:
        smtp.starttls()
        smtp.login(username, password)
        smtp.sendmail(username, to_email, f"Subject: {subject}\n\n{body}")
    print(f"Email sent to {to_email}")


send_email("gallium3171@gmail.com", "Test", "Test test test")
