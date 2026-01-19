#from pkg_install import flatpak, system, custom

#system.install_packages()
#flatpak.install_packages()
#custom.install_packages()


from install import gnome_customization, \
                    tmux, \
                    flatpak

gnome_customization.install()
tmux.install()
flatpak.install()