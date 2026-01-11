# Logic for installing system packages via apt/dnf/pacman
# Detect package manager then install system packages

system::detect_pkg_manager() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
    else
        log INFO "/etc/os-release does not exist. Distro unknown."
        ID="unknown"
    fi

    case "$ID" in
        debian|ubuntu) PKG_MANAGER="apt" ;;
        fedora) PKG_MANAGER="dnf" ;;
        arch) PKG_MANAGER="pacman" ;;
        unknown|*)
            log INFO "Distro unknown: $ID. Detecting package manager via command_exists fallback."
            if command_exists apt; then
                PKG_MANAGER="apt"
            elif command_exists dnf; then
                PKG_MANAGER="dnf"
            elif command_exists pacman; then
                PKG_MANAGER="pacman"
            else
                log ERROR "No supported package manager found."
                return 1
            fi
            ;;
    esac

    log INFO "Detected distro: $ID (package manager: $PKG_MANAGER)"
}


system::pkg_update() {
    log INFO "Updating system package registry."
    case "$PKG_MANAGER" in
        apt) sudo apt update ;;
        dnf) sudo dnf check-update || true ;;
        pacman) sudo pacman -Su --noconfirm ;;
    esac
}

system::pkg_upgrade() {
    log INFO "Upgrading system packages."
}

system::install_packages() {
    log INFO "Installing system packages."
    system::detect_pkg_manager
    system::pkg_update

    local packages=$(
        parse_package_file "$PACKAGES_DIR/system-common.txt"
        parse_package_file "$PACKAGES_DIR/system-$PKG_MANAGER.txt"
    )

    echo $packages
}