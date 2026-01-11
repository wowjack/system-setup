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

# Parse a package list file, stripping comments and empty lines
parse_package_list() {
    local file="$1"
    if [[ -f "$file" ]]; then
        grep -v '^#' "$file" | grep -v '^[[:space:]]*$' | sed 's/[[:space:]]*#.*//'
    fi
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


# Request password once and keep auth cred alive until the script exits
sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &


detect_pkg_manager() {
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
                exit 1
            fi
            ;;
    esac

    log INFO "Detected distro: $ID (package manager: $PKG_MANAGER)"
}


pkg_update() {
    case "$PKG_MANAGER" install
        apt) apt update ;;
        dnf) dnf check-update || true ;;
        pacman) pacman -Su --noconfirm ;;
    esac
}
