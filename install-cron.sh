#!/bin/bash

# install-cron.sh - Cross-platform cron job setup
# Usage: ./install-cron.sh <folder_path> [interval_hours]

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

show_help() {
    echo "Usage: $0 <folder_path> [interval_hours]"
    echo ""
    echo "Arguments:"
    echo "  folder_path      Path to the folder to backup"
    echo "  interval_hours   Hours between backups (default: 4)"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -l, --list      List existing backup cron jobs"
    echo "  -r, --remove    Remove backup cron jobs"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.config/OrcaSlicer           # Every 4 hours"
    echo "  $0 ~/klipper_config 2             # Every 2 hours"
    echo "  $0 --list                         # Show existing jobs"
    echo "  $0 --remove                       # Remove all backup jobs"
}

# Parse command line options
parse_options() {
    LIST_JOBS=false
    REMOVE_JOBS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                LIST_JOBS=true
                shift
                ;;
            -r|--remove)
                REMOVE_JOBS=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$FOLDER_PATH" ]; then
                    FOLDER_PATH="$1"
                elif [ -z "$INTERVAL_HOURS" ]; then
                    INTERVAL_HOURS="$1"
                else
                    print_error "Too many arguments"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Set defaults
    INTERVAL_HOURS="${INTERVAL_HOURS:-4}"
}

# Validate inputs
validate_inputs() {
    if [ "$LIST_JOBS" = true ] || [ "$REMOVE_JOBS" = true ]; then
        return 0
    fi
    
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
    
    # Validate interval
    if ! [[ "$INTERVAL_HOURS" =~ ^[0-9]+$ ]] || [ "$INTERVAL_HOURS" -lt 1 ]; then
        print_error "Interval must be a positive integer (hours)"
        exit 1
    fi
    
    print_success "Input validation passed"
}

# Check if cron is available
check_cron_availability() {
    case $PLATFORM in
        "Linux"|"WSL"|"macOS")
            if ! command -v crontab &> /dev/null; then
                print_error "crontab command not found"
                case $PLATFORM in
                    "Linux"|"WSL")
                        echo "Install with:"
                        echo "  sudo apt install cron         # Ubuntu/Debian"
                        echo "  sudo yum install cronie       # RHEL/CentOS"
                        ;;
                    "macOS")
                        echo "Cron should be available by default on macOS"
                        echo "You might need to give Terminal full disk access in System Preferences"
                        ;;
                esac
                exit 1
            fi
            ;;
        *)
            print_error "Cron jobs not supported on $PLATFORM"
            echo "Consider using Windows Task Scheduler or another scheduling system"
            exit 1
            ;;
    esac
    
    print_success "Cron is available"
}

# Get script directory and backup script
get_script_paths() {
    SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")")"
    BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
    
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        print_error "backup.sh not found at: $BACKUP_SCRIPT"
        echo "Make sure backup.sh is in the same directory as install-cron.sh"
        exit 1
    fi
    
    if [ ! -x "$BACKUP_SCRIPT" ]; then
        print_warning "Making backup.sh executable"
        chmod +x "$BACKUP_SCRIPT"
    fi
    
    # Create log directory
    LOG_DIR="$HOME/.safesync/logs"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/backup-$(basename "$FOLDER_PATH").log"
}

# Generate cron schedule
generate_cron_schedule() {
    # Calculate cron schedule based on interval
    if [ "$INTERVAL_HOURS" -eq 1 ]; then
        CRON_SCHEDULE="0 * * * *"  # Every hour
    elif [ "$INTERVAL_HOURS" -eq 2 ]; then
        CRON_SCHEDULE="0 */2 * * *"  # Every 2 hours
    elif [ "$INTERVAL_HOURS" -eq 4 ]; then
        CRON_SCHEDULE="0 */4 * * *"  # Every 4 hours
    elif [ "$INTERVAL_HOURS" -eq 6 ]; then
        CRON_SCHEDULE="0 */6 * * *"  # Every 6 hours
    elif [ "$INTERVAL_HOURS" -eq 8 ]; then
        CRON_SCHEDULE="0 */8 * * *"  # Every 8 hours
    elif [ "$INTERVAL_HOURS" -eq 12 ]; then
        CRON_SCHEDULE="0 */12 * * *"  # Every 12 hours
    elif [ "$INTERVAL_HOURS" -eq 24 ]; then
        CRON_SCHEDULE="0 0 * * *"  # Daily at midnight
    else
        # For other intervals, use a more complex calculation
        # This is a simplified approach - for complex schedules, users should edit manually
        CRON_SCHEDULE="0 */$INTERVAL_HOURS * * *"
    fi
    
    # Create the full cron job entry
    FOLDER_ID=$(echo "$FOLDER_PATH" | sed 's/[^a-zA-Z0-9]/_/g')
    CRON_COMMENT="# SafeSync auto-backup: $FOLDER_PATH (every ${INTERVAL_HOURS}h)"
    CRON_JOB="$CRON_SCHEDULE $BACKUP_SCRIPT '$FOLDER_PATH' >> '$LOG_FILE' 2>&1"
    CRON_MARKER="safesync_$FOLDER_ID"
}

# List existing backup cron jobs
list_cron_jobs() {
    print_status "Listing existing SafeSync cron jobs..."
    
    # Get current crontab
    CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
    
    if [ -z "$CURRENT_CRON" ]; then
        print_status "No cron jobs found"
        return 0
    fi
    
    # Filter backup-related jobs
    BACKUP_JOBS=$(echo "$CURRENT_CRON" | grep -E "(backup\.sh|# SafeSync)" || echo "")
    
    if [ -z "$BACKUP_JOBS" ]; then
        print_status "No SafeSync backup cron jobs found"
    else
        echo "Current SafeSync backup cron jobs:"
        echo "=================================="
        echo "$BACKUP_JOBS"
        echo "=================================="
    fi
}

# Remove backup cron jobs
remove_cron_jobs() {
    print_status "Removing SafeSync backup cron jobs..."
    
    # Get current crontab
    CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
    
    if [ -z "$CURRENT_CRON" ]; then
        print_status "No cron jobs to remove"
        return 0
    fi
    
    # Remove backup-related jobs
    NEW_CRON=$(echo "$CURRENT_CRON" | grep -v -E "(backup\.sh|# SafeSync)" || echo "")
    
    # Update crontab
    if [ -z "$NEW_CRON" ]; then
        # Remove entire crontab if no jobs left
        crontab -r 2>/dev/null || true
        print_success "All cron jobs removed (crontab cleared)"
    else
        echo "$NEW_CRON" | crontab -
        print_success "SafeSync backup cron jobs removed"
    fi
}

# Install cron job
install_cron_job() {
    print_status "Installing cron job for $FOLDER_PATH"
    print_status "Schedule: Every $INTERVAL_HOURS hours"
    print_status "Cron pattern: $CRON_SCHEDULE"
    
    # Get current crontab
    CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
    
    # Check if job already exists
    if echo "$CURRENT_CRON" | grep -q "$FOLDER_PATH"; then
        print_warning "Cron job for this folder already exists"
        read -p "Replace existing job? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Aborted by user"
            exit 0
        fi
        
        # Remove existing job for this folder
        CURRENT_CRON=$(echo "$CURRENT_CRON" | grep -v "$FOLDER_PATH" || echo "")
    fi
    
    # Add new job
    if [ -n "$CURRENT_CRON" ]; then
        NEW_CRON="$CURRENT_CRON"$'\n'"$CRON_COMMENT"$'\n'"$CRON_JOB"
    else
        NEW_CRON="$CRON_COMMENT"$'\n'"$CRON_JOB"
    fi
    
    # Install new crontab
    echo "$NEW_CRON" | crontab -
    
    print_success "Cron job installed successfully"
    echo ""
    echo "Details:"
    echo "  Folder: $FOLDER_PATH"
    echo "  Schedule: Every $INTERVAL_HOURS hours ($CRON_SCHEDULE)"
    echo "  Log file: $LOG_FILE"
    echo ""
    echo "To monitor logs: tail -f '$LOG_FILE'"
    echo "To list jobs: crontab -l"
    echo "To edit jobs: crontab -e"
}

# Test the backup system
test_backup_system() {
    print_status "Testing backup system..."
    
    if "$BACKUP_SCRIPT" "$FOLDER_PATH" --dry-run >/dev/null 2>&1; then
        print_success "Backup system test passed"
    else
        print_error "Backup system test failed"
        echo "Please check that backup.sh works correctly before installing cron job"
        exit 1
    fi
}

# Platform-specific warnings
show_platform_warnings() {
    case $PLATFORM in
        "WSL")
            print_warning "WSL cron jobs may not run when Windows is sleeping"
            echo "Consider also setting up Windows Task Scheduler for reliability"
            ;;
        "macOS")
            print_warning "macOS may require Full Disk Access for Terminal"
            echo "Go to System Preferences > Security & Privacy > Privacy > Full Disk Access"
            echo "Add Terminal.app if you encounter permission issues"
            ;;
    esac
}

# Main execution
main() {
    echo "============================================"
    echo "  SafeSync Cron Installer"
    echo "============================================"
    echo ""
    
    detect_platform
    parse_options "$@"
    check_cron_availability
    
    if [ "$LIST_JOBS" = true ]; then
        list_cron_jobs
        exit 0
    fi
    
    if [ "$REMOVE_JOBS" = true ]; then
        remove_cron_jobs
        exit 0
    fi
    
    validate_inputs
    get_script_paths
    generate_cron_schedule
    test_backup_system
    install_cron_job
    show_platform_warnings
    
    echo ""
    print_success "Cron installation completed!"
}

# Run main function with all arguments
main "$@"