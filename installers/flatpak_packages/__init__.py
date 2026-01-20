import logging
import pkgutil
import importlib
from util import install_package

def install():
    install_package("flatpak")
    
    logging.info("Installing flatpak packages.")
    for module_info in pkgutil.iter_modules(__path__):
        module = importlib.import_module(f"{__name__}.{module_info.name}")
        
        # Install the package using PACKAGE_NAME variable in module
        package_name = getattr(module, "PACKAGE_NAME", None)
        install_package(package_name, flatpak=True)
        
        # Run the customize function in the module if it exists
        customize_func = getattr(module, "customize", None)
        if callable(customize_func):
            customize_func()
