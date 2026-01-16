#!/usr/bin/env bash

# -e: exit if any command returns an error
# -u: error if any used variable is unset
# -o pipefail: fail if any part of a pipeline fails
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util.sh"

log INFO "Starting install script."

detect_system_package_manager

log INFO "Updating system package registry and installing python."
case "$PKG_MANAGER" in
    apt)
        sudo apt update
        sudo apt install -y python3
        ;;
    dnf)
        sudo dnf -q makecache
        sudo dnf -yq install python3
        ;;
    pacman)
        sudo pacman -Su --noconfirm
        sudo pacman -Sy --noconfirm python
        ;;
esac
log INFO "Python successfully installed."

exec python3 "$SCRIPT_DIR/install.py" --pkg-manager "$PKG_MANAGER"
