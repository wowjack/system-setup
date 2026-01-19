import logging
from pathlib import Path
from util import run
import tomllib

CONFIG_FILE = Path(__file__).resolve().parent / "gnome_config.toml"


def install():
    """Read the gnome config toml file and run all gsettings commands"""
    logging.info("Applying gnome config settings.")
    config = tomllib.loads(CONFIG_FILE.read_text())

    for schema, keys in config.items():
        for key, val in keys.items():
            val = format_val(val)
            logging.debug(f"Setting {schema} {key} to {val}")
            result = run(["gsettings", "set", schema, key, val], check=False)
            # Report errors applying config, but don't fail
            if result.returncode != 0:
                logging.warning(str(result.stderr).strip())

def format_val(val):
    """Ensure the value read from the toml file has the correct format for gsettings command"""
    if isinstance(val, bool):
        return "true" if val else "false"
    elif isinstance(val, list):
        inner = ", ".join(f"'{item}'" for item in val)
        return f"[{inner}]"
    elif isinstance(val, str):
        return f"'{val}'"
    else:
        return str(val)
    