import logging
from util import install_package, run, get_submodules_attributes
import installers.flatpak_packages as this_package


def install():
    # Install flatpak and add flathub remote
    install_package("flatpak")
    run(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub", "https://flathub.org/repo/flathub.flatpakrepo"])
    
    logging.info("Installing flatpak packages.")

    # Install packages using PACKAGE_NAME variable in each module
    [install_package(package_name, flatpak=True) for package_name in get_submodules_attributes(this_package, "PACKAGE_NAME")]


def customize():
    logging.info("Customizing flatpak packages.")
    [customize() for customize in get_submodules_attributes(this_package, "customize")]
