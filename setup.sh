#!/usr/bin/env bash

# -e: exit if any command returns an error
# -u: error if any used variable is unset
# -o pipefail: fail if any part of a pipeline fails
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
CONFIGS_DIR="$SCRIPT_DIR/configs"
LOG_FILE="$SCRIPT_DIR/setup.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


source $SCRIPT_DIR/utils.sh
source $SCRIPT_DIR/flatpak.sh


flatpak::install_packages


echo ""
log INFO "Setup complete! Check $LOG_FILE for details."
