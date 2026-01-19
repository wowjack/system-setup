import logging
from . import font, wallpaper, config

def install():
    logging.info("Customizing Gnome settings.")
    font.install()
    wallpaper.install()
    config.install()

    
    




