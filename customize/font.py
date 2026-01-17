import logging
import zipfile
from util import MEDIA_DIR, run
from pathlib import Path

FONT_ZIP = Path(f"{MEDIA_DIR}/RobotoMono.zip")
FONT_DIR = Path.home() / ".local" / "share" / "fonts"

def install():
    logging.info("Installing RobotoMono Nerd Font")

    FONT_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(FONT_ZIP, "r") as zf:
        for name in zf.namelist():
            if name.endswith(".ttf"):
                zf.extract(name, FONT_DIR)
    run("fc-cache -f")


