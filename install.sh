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
        INFO)  echo -e "[$timestamp] [INFO] $message" ;;
        WARN)  echo -e "[$timestamp] [WARN] $message" ;;
        ERROR) echo -e "[$timestamp] [ERROR] $message" ;;
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


# Detect linux distribution
DISTRO_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --distro)
            DISTRO_OVERRIDE="$2"
            shift 2
            ;;
        *)
            log ERROR "Unknown argument: $1"
            exit 1
            ;;
    esac
done
if [[ -n "$DISTRO_OVERRIDE" ]]; then
    ID="$DISTRO_OVERRIDE"
    log WARN "Using user defined distro name: $ID"
    
elif [[ -f /etc/os-release ]]; then
    log INFO "Reading distro from /etc/os-release"
    source /etc/os-release
else
    log ERROR "/etc/os-release does not exist. Distro unknown."
    exit
fi
log INFO "Installing for $ID"

log INFO "Updating system package repository metadata."
case "$ID" in
    debian)
        sudo apt update
        sudo apt install -yq python3
        ;;
    fedora)
        sudo dnf -q makecache
        sudo dnf -yq install python3
        ;;
    arch)
        sudo pacman -Su --noconfirm
        sudo pacman -Sy --noconfirm python
        ;;
    unknown|*)
        log ERROR "Distro not supported: $ID"
        exit 1
        ;;
esac

log INFO "Python successfully installed."

exec python3 "$SCRIPT_DIR/main.py" --distro "$ID"
