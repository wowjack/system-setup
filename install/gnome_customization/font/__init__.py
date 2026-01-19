import logging
from pathlib import Path
from util import run
import zipfile

FONT_URL = ""
FONT_ZIP = Path(__file__).resolve().parent / "RobotoMono.zip"
FONT_DST = Path.home() / ".local" / "share" / "fonts"

def install():
    """Uncompress the font zip and place files in the correct location, then run gsettings command"""
    logging.info("Installing RobotoMono Nerd Font.")

    FONT_DST.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(FONT_ZIP, "r") as zf:
        for name in zf.namelist():
            if name.endswith(".ttf"):
                zf.extract(name, FONT_DST)
    run(["fc-cache", "-f"])

    run(["gsettings", "set", "org.gnome.desktop.interface", "monospace-font-name", "RobotoMono Nerd Font 12"])