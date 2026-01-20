import logging
import pkgutil
import importlib
from util import install_package, get_submodules_attributes
import installers.system_packages as this_package

def install():
    logging.info("Installing system packages.")
    [install_package(package_name) for package_name in get_submodules_attributes(this_package, "PACKAGE_NAME")]

def customize():
    logging.info("Customizing system packages.")
    [customize() for customize in get_submodules_attributes(this_package, "customize")]