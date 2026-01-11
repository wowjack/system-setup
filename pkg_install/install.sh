source "$SCRIPT_DIR/pkg_install/system.sh"
source "$SCRIPT_DIR/pkg_install/flatpak.sh"
source "$SCRIPT_DIR/pkg_install/custom.sh"

install_packages() {
    system::install_packages
    flatpak::install_packages
    custom::install_packages
}