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
    local packages=$(parse_package_list "$flatpak_file")

    local total=$(echo "$packages" | wc -l)
    local current=0
    local failed=()
    
    while IFS= read -r package; do
        [[ -z "$package" ]] && continue
        
        current=$((current + 1))
        log INFO "[$current/$total] Installing $package..."
        
        # Check if already installed
        if flatpak list --app --columns=application | grep -q "^${package}$"; then
            log OK "$package is already installed"
            continue
        fi
        
        # Install non-interactively
        # -y: assume yes
        # --noninteractive: don't prompt for anything
        if flatpak install --noninteractive -y flathub "$package" 2>> "$LOG_FILE"; then
            log OK "Installed $package"
        else
            log ERROR "Failed to install $package"
            failed+=("$package")
        fi
        
    done <<< "$packages"
    
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