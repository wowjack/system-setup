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

# Parse a package list file, stripping comments and empty lines
parse_package_file() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    sed -e 's/#.*//' \
        -e '/^[[:space:]]*$/d' \
        -e '${/^$/!s/$/\n/}' "$file"
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


