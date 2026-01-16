# Common utility functions and scripts

LOG_FILE="$SCRIPT_DIR/setup.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        INFO)  echo -e "${BLUE}[INFO]${NC} $message" ;;
        OK)    echo -e "${GREEN}[OK]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

command_exists() {
    command -v "$1" &> /dev/null
}

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


detect_system_package_manager() {
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


# Request password once and keep auth cred alive until the script exits
sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &