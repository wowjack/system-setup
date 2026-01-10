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
