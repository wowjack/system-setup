import logging
from pathlib import Path
from util import run, download_file

WALLPAPER_URL = "https://github.com/fedoradesign/backgrounds/blob/f40-backgrounds/default/f40-01-night.png?raw=true"
WALLPAPER_FILE = Path(__file__).resolve().parent / "wallpaper.png"

def install():
    logging.info("Installing fancy wallpaper.")
    download_file(WALLPAPER_URL, WALLPAPER_FILE)
    run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri", f"{WALLPAPER_FILE}"])
    run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri-dark", f"{WALLPAPER_FILE}"])
    run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri", f"{WALLPAPER_FILE}"])