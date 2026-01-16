import subprocess
import sys
from pathlib import Path
import logging

SCRIPT_DIR: Path = Path(__file__).resolve().parent
LOG_FILE: Path = f"{SCRIPT_DIR}/install.log"
PACKAGES_DIR: Path = f"{SCRIPT_DIR}/packages"
CONFIGS_DIR: Path = f"{SCRIPT_DIR}/configs"
CUSTOMIZE_DIR: Path = f"{SCRIPT_DIR}/customize"


def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    # ANSI colors (same as your Bash script)
    BLUE = "\033[94m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    NC = "\033[0m"
    class ColorFormatter(logging.Formatter):
        COLORS = {
            logging.INFO: BLUE,
            logging.WARNING: YELLOW,
            logging.ERROR: RED,
            logging.CRITICAL: RED,
        }
        def format(self, record: logging.LogRecord) -> str:
            color = self.COLORS.get(record.levelno, NC)
            record.levelname = f"{color}{record.levelname}{NC}"
            return super().format(record)

    fmt = "[%(asctime)s] [%(levelname)s] %(message)s"
    datefmt = "%Y-%m-%d %H:%M:%S"

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(ColorFormatter(fmt, datefmt))
    logger.addHandler(console_handler)

    file_handler = logging.FileHandler(LOG_FILE)
    file_handler.setFormatter(logging.Formatter(fmt, datefmt))
    logger.addHandler(file_handler)
setup_logging()



def run(cmd: str, capture=False, check=True, stdout=None, stderr=None) -> subprocess.CompletedProcess:
    cmd = cmd.split()
    
    try:
        return subprocess.run(
            cmd,
            check=check,
            text=True,
            capture_output=capture,
            stdout=stdout,
            stderr=stderr
        )
    except subprocess.CalledProcessError as e:
        if check:
            logging.error(f"Command failed: {' '.join(cmd)}")
            sys.exit(e.returncode)
        return e


def read_package_file(path: Path) -> list[str]:
    path = Path(path)
    if not path.is_file():
        logging.error(f"{path} does not exist.")
        exit(1)
    
    lines = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            lines.append(line)
    return lines



