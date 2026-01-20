import subprocess
import sys
from pathlib import Path
import logging
import urllib.request
import shutil
import argparse

LOG_FILE: Path = Path(__file__).resolve().parent / "install.log"

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



def run(cmd: list[str], exit_on_err=True, stdout_log_level=logging.DEBUG, stderr_log_level=logging.DEBUG) -> subprocess.CompletedProcess:
    """
    Run a command, capturing all output. \\
    If exit_on_err is true, panic if the exit code is not 0. \\
    Log stdout and stderr.
    """
    logging.debug(f"Running command: {' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd,
            text=True,
            check=exit_on_err,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
    except subprocess.CalledProcessError as e:
        # Throw error if check is true
        logging.error(f"Error running command: {' '.join(cmd)}")
        logging.error(e.stderr.strip())
        sys.exit(e.returncode)

    if result.stderr:
        logging.log(stderr_log_level, result.stderr.strip())

    if result.stdout:
        logging.log(stdout_log_level, result.stdout.strip())

    return result



def download_file(url: str, dst: Path) -> None:
    """
    Download a file from url and save it to dst.
    """
    logging.debug(f"Downloading {url} -> {dst}")

    if dst.is_file():
        logging.debug(f"{dst} already exists.")

    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(url) as response:
            with open(dst, "wb") as f:
                shutil.copyfileobj(response, f)
    except Exception:
        logging.error("Failed to download %s", url)
        raise



################################################################
# Package install logic
################################################################

distros = ["debian", "fedora", "arch"]

parser = argparse.ArgumentParser()
parser.add_argument("--distro", choices=distros, required=True)
DISTRO = parser.parse_args().distro
DISTRO_PKG_MANAGERS = {
    "debian": "apt",
    "fedora": "dnf",
    "arch": "pacman"
}
PKG_MANAGER = DISTRO_PKG_MANAGERS[DISTRO]
PKG_MANAGER_CMDS = {
    "apt": (["dpkg", "-s"], ["sudo", "apt-get", "install", "-yq"]),
    "dnf": (["rpm", "-q"], ["sudo", "dnf", "install", "-yq"]),
    "pacman": (["pacman", "-Qi"], ["sudo", "pacman", "-S", "--noconfirm"]),
    "flatpak": (["flatpak", "info", "--user"], ["flatpak", "install", "--user", "--noninteractive", "-y", "flathub"])
}


def install_package(package: str | dict, flatpak=False):
    if isinstance(package, dict):
        package = package[DISTRO]

    manager = "flatpak" if flatpak else PKG_MANAGER
    (check, install) = PKG_MANAGER_CMDS[manager]

    logging.info(f"Installing {manager} {package}")
    if run(check + [package], exit_on_err=False).returncode == 0:
        logging.debug(f"{package} already installed")
        return
    run(install + [package])
    logging.debug(f"{package} installed successfully.")
