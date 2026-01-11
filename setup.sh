#!/usr/bin/env bash

# -e: exit if any command returns an error
# -u: error if any used variable is unset
# -o pipefail: fail if any part of a pipeline fails
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/util.sh"
source "$SCRIPT_DIR/pkg_install/install.sh"
source "$SCRIPT_DIR/wallpaper.sh"

log INFO "Starting setup script."

# Install all system, flatpak, and custom packages
install_packages

# fetch and set the nice wallpaper I like
wallpaper::install


echo ""
log INFO "Setup complete! Check $LOG_FILE for details."
