import os
import logging

def create_path(*local_paths: str) -> str:
    """Creates a path relative to the current folder.

    `local_paths`: folders or files to append to path, e.g. `"logs"`, `"notifications.py"`.
    """
    return os.path.abspath(os.path.join(*local_paths))

def create_log_path(log_file: str):
    """Creates a logging filepath to be passed into `logging.basicConfig`.

    `log_file`: pass `__file__` into the function.
    """
    return create_path("logs", f"{os.path.basename(log_file)[:-3]}.log")

def config_log():
    """Configures the logging system."""
    log_dir = create_path("logs")  # Path to the logs directory
    os.makedirs(log_dir, exist_ok=True)  # Ensure the logs directory exists

    logging.basicConfig(
        filename=create_path("logs", "backend.log"),  # Log file path
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )
