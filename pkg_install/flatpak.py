import subprocess
from util import PACKAGES_DIR, read_package_file, run
from pathlib import Path
import logging

PACKAGE_FILE: Path = PACKAGES_DIR / "flatpak.txt"
PACKAGES = read_package_file(PACKAGE_FILE)

def install_packages():
    logging.info("Adding flathub remote")
    run("flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo")

    logging.info("Installing flatpak packages.")

    total = len(PACKAGES)
    for (num, pkg) in enumerate(PACKAGES):
        logging.info(f"[{num+1}/{total}] Installing {pkg}")

        if run(f"flatpak info --user {pkg}", exit_on_err=False).returncode == 0:
            logging.debug(f"{pkg} already installed.")
            continue

        run(f"flatpak install --user --noninteractive -y flathub {pkg}")
        logging.debug(f"{pkg} installed successfully.")