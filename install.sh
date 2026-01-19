#!/usr/bin/env bash

# -e: exit if any command returns an error
# -u: error if any used variable is unset
# -o pipefail: fail if any part of a pipeline fails
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup logging
LOG_FILE="$SCRIPT_DIR/install.log"
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        INFO)  echo -e "[INFO] $message" ;;
        OK)    echo -e "[OK] $message" ;;
        WARN)  echo -e "[WARN] $message" ;;
        ERROR) echo -e "[ERROR] $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Capture errors
error_handler() {
    local exit_code="$1"
    local line_no="$2"
    local command="$3"
    local src="${BASH_SOURCE[1]}"

    log ERROR "Command failed (exit code $exit_code)"
    log ERROR "File: $src"
    log ERROR "Line: $line_no"
    log ERROR "Command: $command"

    exit "$exit_code"
}
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR


###################################################################
# Begin Installation
###################################################################

log INFO "Starting install script."

# Request password once and keep auth cred alive until the script exits
sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

log INFO "Detecting system package manager"
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
        log INFO "Distro unknown: $ID. Detecting package manager via command exists fallback."
        if command -v apt &> /dev/null; then
            PKG_MANAGER="apt"
        elif command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
        elif command -v pacman &> /dev/null; then
            PKG_MANAGER="pacman"
        else
            log ERROR "No supported package manager found."
            return 1
        fi
        ;;
esac
log INFO "Detected distro: $ID (package manager: $PKG_MANAGER)"

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

exec python3 "$SCRIPT_DIR/main.py" --pkg-manager "$PKG_MANAGER"
