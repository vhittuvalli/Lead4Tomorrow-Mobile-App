# L4T-Calendar-App

Codebase for the development of a calendar app for [Lead4Tomorrow](https://lead4tomorrow.org/).

## Back-End Calendar Entry Formatting
```
{
    "1": { # month (Jan)
        "theme": "Anti-Bullying Month", # monthly theme
        "entries": {
            "1": "Brainstorm...", # daily entry
            "2": "Today is..."
        }
    }
}
```

## Back-End Profiles Formatting
```
{
    "1": { # User ID
        "time": "09:00", # Time to send notification
        "phone": "",
        "email": "johndoe123@gmail.com",
        "method": "email" # Notification method (phone, email, push)
    },
    "2": {
        "time": "10:00",
        "phone": "784-239-2938",
        "email": "",
        "method": "phone"
    },
}
```