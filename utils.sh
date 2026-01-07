#!/bin/bash
# Utility functions for vina-bash scripts
# Provides common functionality for error handling, logging, and validation

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="vina_pipeline.log"

#######################################
# Print error message and exit
# Arguments:
#   Error message
#######################################
error_exit() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    exit 1
}

#######################################
# Print warning message
# Arguments:
#   Warning message
#######################################
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

#######################################
# Print info message
# Arguments:
#   Info message
#######################################
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

#######################################
# Print success message
# Arguments:
#   Success message
#######################################
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

#######################################
# Check if a command exists
# Arguments:
#   Command name
# Returns:
#   0 if command exists, 1 otherwise
#######################################
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

#######################################
# Check if required commands are available
# Arguments:
#   List of required commands
#######################################
check_dependencies() {
    local missing_deps=()
    
    for cmd in "$@"; do
        if ! check_command "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error_exit "Missing required dependencies: ${missing_deps[*]}"
    fi
}

#######################################
# Check if file exists
# Arguments:
#   File path
#######################################
check_file() {
    if [ ! -f "$1" ]; then
        error_exit "File not found: $1"
    fi
}

#######################################
# Create directory if it doesn't exist
# Arguments:
#   Directory path
#######################################
ensure_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1" || error_exit "Failed to create directory: $1"
        info "Created directory: $1"
    fi
}

#######################################
# Show progress bar
# Arguments:
#   Current value
#   Total value
#   Description
#######################################
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[INFO]${NC} %s [" "$description"
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %d%%" "$percent"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

#######################################
# Validate PDBQT file format
# Arguments:
#   PDBQT file path
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_pdbqt() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Check if file has PDBQT markers
    if ! grep -q "^ATOM\|^HETATM" "$file"; then
        return 1
    fi
    
    return 0
}

#######################################
# Get file count matching pattern
# Arguments:
#   Pattern (e.g., "*.pdbqt")
# Returns:
#   Count of matching files
#######################################
count_files() {
    local pattern=$1
    local count=0
    
    for file in $pattern; do
        if [ -f "$file" ]; then
            count=$((count + 1))
        fi
    done
    
    echo "$count"
}

#######################################
# Clean temporary files
# Arguments:
#   Pattern of files to clean
#######################################
cleanup_temp_files() {
    local pattern=$1
    
    if [ -n "$pattern" ]; then
        info "Cleaning up temporary files: $pattern"
        rm -f $pattern 2>/dev/null || true
    fi
}

#######################################
# Initialize log file
#######################################
init_log() {
    echo "===== Vina Pipeline Log - $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$LOG_FILE"
}
