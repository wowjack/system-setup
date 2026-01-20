PACKAGE_NAME = "git"

import logging
import os
from pathlib import Path
from util import run

CURR_DIR = Path(__file__).resolve().parent
CONFIG_FILE = CURR_DIR / ".gitconfig"
CONFIG_DST = Path.home() / ".gitconfig"
KEY_FILE = CURR_DIR / ""
KEY_DST = Path.home() / ".ssh" / "id_ed25519"

def customize():
    logging.debug("Installing git config file")
    os.link(CONFIG_FILE, CONFIG_DST)

    run(["ssh-keygen"])