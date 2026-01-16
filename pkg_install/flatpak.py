import subprocess
from util import PACKAGES_DIR, read_package_file, run
from pathlib import Path
import logging

PACKAGE_FILE: Path = f"{PACKAGES_DIR}/flatpak.txt"
PACKAGES = read_package_file(PACKAGE_FILE)

def install_packages():
    logging.info("Installing flatpak packages.")
    
    run("flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo", check=False)

    for pkg in PACKAGES:
        if run(f"flatpak info {pkg}", check=False, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE) == 0:
            logging.info(f"{pkg} already installed.")
            continue

        run(f"flatpak install --noninteractive -y flathub {pkg}")
        logging.info(f"{pkg} installed successfully.")