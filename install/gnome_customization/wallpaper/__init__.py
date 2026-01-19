import logging
from pathlib import Path
from util import run

WALLPAPER_URL = ""
WALLPAPER_FILE = Path(__file__).resolve().parent / "wallpaper.png"

def install():
    logging.info("Installing fancy wallpaper.")
    run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri", WALLPAPER_FILE])
    run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri-dark", WALLPAPER_FILE])
    run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri", WALLPAPER_FILE])