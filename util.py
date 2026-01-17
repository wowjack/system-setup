import subprocess
import sys
from pathlib import Path
import logging

SCRIPT_DIR: Path = Path(__file__).resolve().parent
LOG_FILE: Path = SCRIPT_DIR / "install.log"
PACKAGES_DIR: Path = SCRIPT_DIR / "packages"
CONFIGS_DIR: Path = SCRIPT_DIR / "configs"
CUSTOMIZE_DIR: Path = SCRIPT_DIR / "customize"
MEDIA_DIR: Path = SCRIPT_DIR / "media"


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



def run(cmd: str, check=True) -> subprocess.CompletedProcess:
    cmd = cmd.split()
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


def read_package_file(file_path: Path) -> list[str]:
    file_path = Path(file_path)
    if not file_path.is_file():
        logging.error(f"{file_path} does not exist.")
        exit(1)
    
    lines = []
    with file_path.open() as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            lines.append(line)
    return lines



