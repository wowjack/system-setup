flatpak::install_packages() {
    log INFO "Starting Flatpak package installation..."
    
    local flatpak_file="$PACKAGES_DIR/flatpak.txt"
    
    if [[ ! -f "$flatpak_file" ]]; then
        log WARN "No flatpak.txt found at $flatpak_file, skipping Flatpak packages"
        return 0
    fi
    
    # Ensure Flatpak is installed
    if ! command_exists flatpak; then
        log ERROR "Flatpak is not installed. Please install Flatpak first."
        return 1
    fi
    
    # Add Flathub repository if not already added
    if ! flatpak remotes | grep -q flathub; then
        log INFO "Adding Flathub repository..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
    
    # Read packages and install
    mapfile -t packages < <(parse_package_file "$flatpak_file")

    local total=${#packages[@]}
    local failed=()
    
    for i in "${!packages[@]}"; do
        local package=${packages[i]}
        log INFO "[$((i + 1))/$total] Installing $package..."
        flatpak::install_package "$package"
    done
    
    # Summary
    echo ""
    log INFO "Flatpak installation complete"
    if [[ ${#failed[@]} -gt 0 ]]; then
        log WARN "Failed to install ${#failed[@]} package(s):"
        for pkg in "${failed[@]}"; do
            log WARN "  - $pkg"
        done
        return 1
    fi
    
    return 0
}



flatpak::install_package() {
    local pkg="$1"
    # Check if already installed
    if flatpak list --app --columns=application | grep -q "^${pkg}$"; then
        log OK "$package is already installed"
    elif flatpak install --noninteractive -y flathub "$pkg" 2>> "$LOG_FILE"; then
        log OK "Installed $pkg"
    else
        log ERROR "Failed to install $pkg"
        failed+=("$pkg")
    fi
}