import logging
from util import run, CONFIGS_DIR, MEDIA_DIR
from pathlib import Path
import tomllib

CONFIG_FILE = Path(f"{CONFIGS_DIR}/gnome-config.toml")


def customize():
    logging.info("Customizing Gnome settings.")

    raw_text = CONFIG_FILE.read_text().replace("${MEDIA_DIR}", str(MEDIA_DIR))
    config = tomllib.loads(raw_text)

    for schema, keys in config.items():
        for key, val in keys.items():
            val = format_val(val)
            logging.debug(f"Setting {schema} {key} to {val}")
            logging.debug(f"gsettings set {schema} {key} {val}")
            #run(f"gsettings set {schema} {key} {val}")
    
    
def format_val(val):
    if isinstance(val, bool):
        return "true" if val else "false"
    elif isinstance(val, list):
        inner = ", ".join(f"'{item}'" for item in val)
        return f"[{inner}]"
    elif isinstance(val, str):
        return f"'{val}'"
    else:
        return str(val)