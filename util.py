import subprocess
import sys
from pathlib import Path
import logging

SCRIPT_DIR: Path = Path(__file__).resolve().parent
LOG_FILE: Path = SCRIPT_DIR / "install.log"

def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    logger.propagate = False
    logger.handlers.clear()

    fmt = "[%(asctime)s] [%(levelname)s] %(message)s"
    datefmt = "%Y-%m-%d %H:%M:%S"

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(logging.Formatter(fmt, datefmt))
    logger.addHandler(console_handler)

    file_handler = logging.FileHandler(LOG_FILE)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(logging.Formatter(fmt, datefmt))
    logger.addHandler(file_handler)
setup_logging()



def run(cmd: list[str], check=True) -> subprocess.CompletedProcess:
    """
    Run a command, capturing all output. \\
    If check is true, panic if the exit code is not 0. \\
    Log stdout and stderr as debug to log file.
    """
    try:
        result = subprocess.run(
            cmd,
            text=True,
            check=check,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
    except subprocess.CalledProcessError as e:
        # Throw error if check is true
        logging.error(f"Error running command: {' '.join(cmd)}")
        logging.error(e.stderr.strip())
        sys.exit(e.returncode)

    if result.stderr:
        logging.debug(result.stderr.strip())

    if result.stdout:
        logging.debug(result.stdout.strip())

    return result




