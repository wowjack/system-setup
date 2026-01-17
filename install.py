from pkg_install import flatpak, system, custom
from customize import gnome

system.install_packages()
flatpak.install_packages()
custom.install_packages()

gnome.customize()