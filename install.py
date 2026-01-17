from pkg_install import flatpak, system, custom
from customize import font, gnome

system.install_packages()
flatpak.install_packages()
custom.install_packages()

font.install()
gnome.customize()