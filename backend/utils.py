"File that holds utility functions for the back-end"

import os
import logging


def create_path(*local_paths: str) -> str:
    """Creates a path to ~/Lead4Tomorrow-Mobile-App/<local paths>

    `local_paths`: folders or files to append to path, e.g. `"backend"`, `"notifications.py"`; same functionality as `os.path.join`
    """
    return os.path.abspath(os.path.join(*local_paths))


def create_log_path(log_file: str):
    """Creates a logfing filepath to be passed into `logging.basicConfig`

    `log_file`: pass `__file__` into the function.
    """
    return create_path("backend", "logs", f"{os.path.basename(log_file)[:-3]}.log")


def config_log():
    logging.basicConfig(
        filename=create_path("backend", "logs", f"backend.log"), level=logging.INFO
    )
