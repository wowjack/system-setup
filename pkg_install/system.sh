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


apt::install_package() {
    local pkg="$1"

    if dpkg -s "$pkg" &> /dev/null; then
        log OK "$pkg is already installed"
    elif sudo apt install -y "$pkg" 2>> "$LOG_FILE"; then
        log OK "Installed $pkg"
    else
        log ERROR "Failed to install $pkg"
        failed+=("$pkg")
    fi
}

dnf::install_package() {
    return 1
}

pacman::install_package() {
    return 1
}


system::install_packages() {
    log INFO "Installing system packages."
    system::detect_pkg_manager
    system::pkg_update

    mapfile -t packages < <(
        parse_package_file "$PACKAGES_DIR/system-common.txt"
        parse_package_file "$PACKAGES_DIR/system-$PKG_MANAGER.txt"
    )

    local total=${#packages[@]}
    local failed=()

    for i in "${!packages[@]}"; do
        local package=${packages[i]}
        log INFO "[$((i + 1))/$total] Installing $package..."
        "$PKG_MANAGER"::install_package "$package"
    done
    
    # Summary
    echo ""
    log INFO "$PKG_MANAGER installation complete"
    if [[ ${#failed[@]} -gt 0 ]]; then
        log WARN "Failed to install ${#failed[@]} package(s):"
        for pkg in "${failed[@]}"; do
            log WARN "  - $pkg"
        done
        return 1
    fi
    
    return 0
}