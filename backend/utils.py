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

    log_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    log_level = logging.DEBUG  # Set to DEBUG for detailed logs

    # File Handler
    file_handler = logging.FileHandler(create_path("logs", "backend.log"))
    file_handler.setLevel(log_level)
    file_handler.setFormatter(logging.Formatter(log_format))

    # Console Handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(log_level)
    console_handler.setFormatter(logging.Formatter(log_format))

    # Configure the logger with both handlers
    logging.basicConfig(
        level=log_level,
        handlers=[file_handler, console_handler],
    )

