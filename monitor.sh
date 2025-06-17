#!/bin/bash

# monitor.sh - Cross-platform file monitoring
# Usage: ./monitor.sh <folder_path> [options]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Platform detection
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                PLATFORM="WSL"
            else
                PLATFORM="Linux"
            fi
            ;;
        Darwin*)    PLATFORM="macOS";;
        CYGWIN*)    PLATFORM="Cygwin";;
        MINGW*)     PLATFORM="MinGW";;
        MSYS*)      PLATFORM="MSYS";;
        *)          PLATFORM="Unknown";;
    esac
}

# Parse command line options
parse_options() {
    VERBOSE=false
    DELAY=10
    EVENTS=""
    EXCLUDE_PATTERNS=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--delay)
                DELAY="$2"
                shift 2
                ;;
            -e|--events)
                EVENTS="$2"
                shift 2
                ;;
            --exclude)
                EXCLUDE_PATTERNS="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$FOLDER_PATH" ]; then
                    FOLDER_PATH="$1"
                else
                    print_error "Too many arguments"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

show_help() {
    echo "Usage: $0 <folder_path> [options]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose         Show detailed output"
    echo "  -d, --delay SECONDS   Delay after detecting changes (default: 10)"
    echo "  -e, --events EVENTS   File events to monitor (platform specific)"
    echo "  --exclude PATTERNS    Exclude patterns (comma separated)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.config/OrcaSlicer"
    echo "  $0 ~/klipper_config --delay 5 --verbose"
    echo "  $0 /path/to/folder --exclude '*.log,*.tmp'"
    echo ""
    echo "Platform-specific events:"
    echo "  Linux/WSL: modify,create,delete,move,attrib"
    echo "  macOS: (uses fswatch - see 'man fswatch' for details)"
}

# Check dependencies
check_dependencies() {
    case $PLATFORM in
        "Linux"|"WSL")
            if ! command -v inotifywait &> /dev/null; then
                print_error "inotify-tools not installed"
                echo "Install with:"
                echo "  sudo apt install inotify-tools    # Ubuntu/Debian"
                echo "  sudo yum install inotify-tools    # RHEL/CentOS"
                exit 1
            fi
            MONITOR_CMD="inotifywait"
            ;;
        "macOS")
            if ! command -v fswatch &> /dev/null; then
                print_error "fswatch not installed"
                echo "Install with:"
                echo "  brew install fswatch"
                exit 1
            fi
            MONITOR_CMD="fswatch"
            ;;
        *)
            print_error "File monitoring not supported on $PLATFORM"
            echo "Supported platforms: Linux, WSL, macOS"
            exit 1
            ;;
    esac
    
    print_success "File monitoring tools available ($MONITOR_CMD)"
}

# Validate inputs
validate_inputs() {
    if [ -z "$FOLDER_PATH" ]; then
        print_error "Folder path is required"
        show_help
        exit 1
    fi
    
    # Expand tilde and resolve path
    FOLDER_PATH=$(eval echo "$FOLDER_PATH")
    FOLDER_PATH=$(realpath "$FOLDER_PATH" 2>/dev/null || echo "$FOLDER_PATH")
    
    if [ ! -d "$FOLDER_PATH" ]; then
        print_error "Folder does not exist: $FOLDER_PATH"
        exit 1
    fi
    
    if [ ! -d "$FOLDER_PATH/.git" ]; then
        print_error "Not a Git repository: $FOLDER_PATH"
        echo "Run setup-backup.sh first to initialize the backup system."
        exit 1
    fi
    
    # Validate delay
    if ! [[ "$DELAY" =~ ^[0-9]+$ ]]; then
        print_error "Delay must be a positive integer"
        exit 1
    fi
    
    print_success "Input validation passed"
}

# Get script directory for backup script location
get_script_dir() {
    SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")")"
    BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
    
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        print_error "backup.sh not found at: $BACKUP_SCRIPT"
        echo "Make sure backup.sh is in the same directory as monitor.sh"
        exit 1
    fi
    
    if [ ! -x "$BACKUP_SCRIPT" ]; then
        print_warning "Making backup.sh executable"
        chmod +x "$BACKUP_SCRIPT"
    fi
}

# Build exclude patterns for monitoring
build_exclude_patterns() {
    local patterns="$EXCLUDE_PATTERNS"
    
    # Add common patterns to exclude
    local common_excludes=".git,*.tmp,*.log,*~,*.swp,*.swo,.DS_Store,Thumbs.db"
    
    if [ -n "$patterns" ]; then
        patterns="$patterns,$common_excludes"
    else
        patterns="$common_excludes"
    fi
    
    FINAL_EXCLUDE_PATTERNS="$patterns"
    
    if [ "$VERBOSE" = true ]; then
        print_status "Excluding patterns: $FINAL_EXCLUDE_PATTERNS"
    fi
}

# Linux/WSL monitoring using inotifywait
monitor_linux() {
    local events="${EVENTS:-modify,create,delete,move,attrib}"
    local exclude_args=""
    
    # Build exclude arguments
    if [ -n "$FINAL_EXCLUDE_PATTERNS" ]; then
        IFS=',' read -ra patterns <<< "$FINAL_EXCLUDE_PATTERNS"
        for pattern in "${patterns[@]}"; do
            exclude_args="$exclude_args --exclude $pattern"
        done
    fi
    
    print_status "Starting file monitoring (Linux/WSL)"
    print_status "Events: $events"
    print_status "Delay: ${DELAY}s after change detection"
    print_status "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        if [ "$VERBOSE" = true ]; then
            print_status "Waiting for file changes in $FOLDER_PATH..."
        fi
        
        # Wait for file system events
        if inotifywait -r -e "$events" $exclude_args "$FOLDER_PATH" 2>/dev/null; then
            if [ "$VERBOSE" = true ]; then
                print_status "Change detected, waiting ${DELAY} seconds for operations to complete..."
            else
                echo "Change detected, waiting ${DELAY}s..."
            fi
            
            sleep "$DELAY"
            
            print_status "Running backup..."
            if [ "$VERBOSE" = true ]; then
                "$BACKUP_SCRIPT" "$FOLDER_PATH" --verbose
            else
                "$BACKUP_SCRIPT" "$FOLDER_PATH"
            fi
            
            echo ""
        fi
    done
}

# macOS monitoring using fswatch
monitor_macos() {
    local fswatch_args="-o"  # Numeric output mode
    
    # Add exclude patterns
    if [ -n "$FINAL_EXCLUDE_PATTERNS" ]; then
        IFS=',' read -ra patterns <<< "$FINAL_EXCLUDE_PATTERNS"
        for pattern in "${patterns[@]}"; do
            fswatch_args="$fswatch_args -e $pattern"
        done
    fi
    
    print_status "Starting file monitoring (macOS)"
    print_status "Delay: ${DELAY}s after change detection"
    print_status "Press Ctrl+C to stop"
    echo ""
    
    # Use fswatch with numeric output
    fswatch $fswatch_args "$FOLDER_PATH" | while read num; do
        if [ "$VERBOSE" = true ]; then
            print_status "Changes detected ($num events), waiting ${DELAY} seconds..."
        else
            echo "Changes detected, waiting ${DELAY}s..."
        fi
        
        sleep "$DELAY"
        
        print_status "Running backup..."
        if [ "$VERBOSE" = true ]; then
            "$BACKUP_SCRIPT" "$FOLDER_PATH" --verbose
        else
            "$BACKUP_SCRIPT" "$FOLDER_PATH"
        fi
        
        echo ""
    done
}

# Signal handling for graceful shutdown
cleanup_on_exit() {
    echo ""
    print_status "File monitoring stopped"
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    exit 0
}

# Set up signal traps
setup_signal_handling() {
    trap cleanup_on_exit INT TERM
    
    # Handle script termination gracefully
    trap 'echo ""; print_warning "Monitoring interrupted"' HUP
}

# Show monitoring status
show_status() {
    echo "============================================"
    echo "  SafeSync File Monitoring"
    echo "============================================"
    echo "Platform: $PLATFORM"
    echo "Monitor tool: $MONITOR_CMD"
    echo "Target folder: $FOLDER_PATH"
    echo "Backup script: $BACKUP_SCRIPT"
    echo "Delay: ${DELAY}s"
    echo "Verbose: $VERBOSE"
    if [ -n "$FINAL_EXCLUDE_PATTERNS" ]; then
        echo "Excluding: $FINAL_EXCLUDE_PATTERNS"
    fi
    echo "============================================"
    echo ""
}

# Test backup system before starting monitoring
test_backup_system() {
    print_status "Testing backup system..."
    
    if "$BACKUP_SCRIPT" "$FOLDER_PATH" --dry-run >/dev/null 2>&1; then
        print_success "Backup system test passed"
    else
        print_error "Backup system test failed"
        echo "Please check that backup.sh works correctly before starting monitoring"
        exit 1
    fi
}

# Main monitoring function
start_monitoring() {
    case $PLATFORM in
        "Linux"|"WSL")
            monitor_linux
            ;;
        "macOS")
            monitor_macos
            ;;
        *)
            print_error "Monitoring not implemented for $PLATFORM"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    detect_platform
    parse_options "$@"
    validate_inputs
    check_dependencies
    get_script_dir
    build_exclude_patterns
    setup_signal_handling
    
    if [ "$VERBOSE" = true ]; then
        show_status
    fi
    
    test_backup_system
    start_monitoring
}

# Run main function with all arguments
main "$@"