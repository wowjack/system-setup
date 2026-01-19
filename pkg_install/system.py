# I understand that package repositories differ across distros of the same family,
# but I only anticipate potentially using debian, fedora, or arch


import argparse
from util import PACKAGES_DIR, run, read_package_file
from pathlib import Path
import logging

parser = argparse.ArgumentParser()
parser.add_argument("--pkg-manager", choices=["apt", "dnf", "pacman"], required=True)
PKG_MANAGER = parser.parse_args().pkg_manager

COMMON_PACKAGE_FILE: Path = PACKAGES_DIR / "system-common.txt"
PACKAGE_FILE: Path = PACKAGES_DIR / f"system-{PKG_MANAGER}.txt"
PACKAGES = read_package_file(COMMON_PACKAGE_FILE) + read_package_file(PACKAGE_FILE)


def apt_update():
    run("sudo apt update")
def apt_check_package_exists(pkg: str) -> bool:
    return run(f"dpkg -s {pkg}", check=False).returncode == 0
def apt_install(pkg: str):
    run(f"sudo apt install -y {pkg}")

def dnf_update():
    run("sudo dnf -q makecache")
def dnf_check_package_exists(pkg: str) -> bool:
    return run(f"rpm -q {pkg}", check=False).returncode == 0
def dnf_install(pkg: str):
    run(f"sudo dnf -yq install {pkg}")

def pacman_update():
    run("sudo pacman -Sy")
def pacman_check_package_exists(pkg: str) -> bool:
    return run(f"pacman -Qi {pkg}", check=False).returncode == 0
def pacman_install(pkg: str):
    run(f"sudo pacman -S --noconfirm {pkg}")

PKG_FUNCS = {
    "apt": (apt_update, apt_check_package_exists, apt_install),
    "dnf": (dnf_update, dnf_check_package_exists, dnf_install),
    "pacman": (pacman_update, pacman_check_package_exists, pacman_install)
}


def install_packages():
    (update, check, install) = PKG_FUNCS[PKG_MANAGER] 

    logging.info(f"Updating {PKG_MANAGER} packages.")
    update()

    logging.info(f"Installing {PKG_MANAGER} packages.")

    total = len(PACKAGES)
    for (num, pkg) in enumerate(PACKAGES):
        logging.info(f"[{num+1}/{total}] Installing {pkg}")

        if check(pkg):
            logging.debug(f"{pkg} already installed.")
            continue

        install(pkg)
        logging.debug(f"{pkg} installed successfully.")



    