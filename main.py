import pkgutil
import importlib

for module_info in pkgutil.iter_modules(["installers"]):
    module = importlib.import_module(f"installers.{module_info.name}")
    getattr(module, "install", None)()