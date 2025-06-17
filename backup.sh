#!/bin/bash

# backup.sh - Cross-platform backup execution
# Usage: ./backup.sh <folder_path> [options]

set -e  # Exit on any error

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
    FORCE_PUSH=false
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE_PUSH=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
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
    echo "  -v, --verbose    Show detailed output"
    echo "  -f, --force      Force push even if it fails initially"
    echo "  -n, --dry-run    Show what would be done without doing it"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.config/OrcaSlicer"
    echo "  $0 ~/klipper_config --verbose"
    echo "  $0 /path/to/folder --dry-run"
}

# Validate inputs
validate_inputs() {
    if [ -z "$FOLDER_PATH" ]; then
        FOLDER_PATH="$(pwd)"
        print_status "No folder specified, using current directory: $FOLDER_PATH"
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
}

# Check Git status and health
check_git_health() {
    cd "$FOLDER_PATH"
    
    # Check if we have a remote configured
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_warning "No remote repository configured"
        print_status "Changes will be committed locally only"
        REMOTE_AVAILABLE=false
    else
        REMOTE_AVAILABLE=true
        if [ "$VERBOSE" = true ]; then
            print_status "Remote repository: $(git remote get-url origin)"
        fi
    fi
    
    # Check current branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "master")
    if [ "$VERBOSE" = true ]; then
        print_status "Current branch: $CURRENT_BRANCH"
    fi
    
    # Check for uncommitted changes in index
    if ! git diff --cached --quiet; then
        print_warning "There are staged changes that haven't been committed"
    fi
}

# Get repository statistics
get_repo_stats() {
    cd "$FOLDER_PATH"
    
    # Count files
    TOTAL_FILES=$(find . -type f ! -path './.git/*' | wc -l)
    
    # Get repository size
    if command -v du >/dev/null 2>&1; then
        case $PLATFORM in
            "macOS")
                REPO_SIZE=$(du -sh . 2>/dev/null | cut -f1 || echo "unknown")
                ;;
            *)
                REPO_SIZE=$(du -sh . 2>/dev/null | cut -f1 || echo "unknown")
                ;;
        esac
    else
        REPO_SIZE="unknown"
    fi
    
    # Get last commit info
    LAST_COMMIT=$(git log -1 --format="%h - %s (%cr)" 2>/dev/null || echo "No commits yet")
    
    if [ "$VERBOSE" = true ]; then
        print_status "Repository statistics:"
        echo "  Files: $TOTAL_FILES"
        echo "  Size: $REPO_SIZE"
        echo "  Last commit: $LAST_COMMIT"
    fi
}

# Check for changes
check_changes() {
    cd "$FOLDER_PATH"
    
    # Get status
    STATUS_OUTPUT=$(git status --porcelain)
    
    if [ -z "$STATUS_OUTPUT" ]; then
        print_status "No changes detected"
        return 1
    fi
    
    # Count changes by type
    MODIFIED=$(echo "$STATUS_OUTPUT" | grep -c "^ M" || true)
    ADDED=$(echo "$STATUS_OUTPUT" | grep -c "^A" || true)
    DELETED=$(echo "$STATUS_OUTPUT" | grep -c "^ D" || true)
    UNTRACKED=$(echo "$STATUS_OUTPUT" | grep -c "^??" || true)
    
    print_status "Changes detected:"
    [ $MODIFIED -gt 0 ] && echo "  Modified: $MODIFIED files"
    [ $ADDED -gt 0 ] && echo "  Added: $ADDED files"
    [ $DELETED -gt 0 ] && echo "  Deleted: $DELETED files"
    [ $UNTRACKED -gt 0 ] && echo "  Untracked: $UNTRACKED files"
    
    if [ "$VERBOSE" = true ]; then
        echo ""
        print_status "Changed files:"
        echo "$STATUS_OUTPUT" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
    
    return 0
}

# Create commit
create_commit() {
    cd "$FOLDER_PATH"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would add all changes and create commit"
        return 0
    fi
    
    print_status "Adding changes to Git..."
    git add .
    
    # Create commit message with timestamp and platform info
    COMMIT_MSG="Automatic backup $(date '+%Y-%m-%d %H:%M:%S')"
    
    if [ "$VERBOSE" = true ]; then
        COMMIT_MSG="$COMMIT_MSG

Platform: $PLATFORM
Files: $TOTAL_FILES
Repository size: $REPO_SIZE

Changes in this commit:
$(git diff --cached --stat)"
    fi
    
    git commit -m "$COMMIT_MSG"
    print_success "Changes committed locally"
}

# Push to remote
push_to_remote() {
    if [ "$REMOTE_AVAILABLE" != true ]; then
        print_status "No remote repository configured, skipping push"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would push to remote repository"
        return 0
    fi
    
    cd "$FOLDER_PATH"
    
    print_status "Pushing to remote repository..."
    
    # Try to push
    if git push origin "$CURRENT_BRANCH" 2>/dev/null; then
        print_success "Successfully pushed to remote repository"
        return 0
    fi
    
    # Push failed, check why
    print_warning "Initial push failed"
    
    if [ "$FORCE_PUSH" = true ]; then
        print_status "Attempting force push..."
        if git push --force-with-lease origin "$CURRENT_BRANCH" 2>/dev/null; then
            print_success "Force push successful"
            return 0
        else
            print_error "Force push also failed"
        fi
    fi
    
    # Provide helpful error information
    print_status "Possible solutions:"
    echo "1. Check internet connection"
    echo "2. Verify repository exists on remote"
    echo "3. Check authentication (SSH keys or credentials)"
    echo "4. Try manual push: cd '$FOLDER_PATH' && git push origin $CURRENT_BRANCH"
    
    # Don't exit with error - local commit is still valuable
    print_warning "Changes are committed locally but not pushed to remote"
    return 1
}

# Cleanup and maintenance
cleanup_repo() {
    if [ "$DRY_RUN" = true ]; then
        return 0
    fi
    
    cd "$FOLDER_PATH"
    
    # Clean up Git repository (remove dangling objects, etc.)
    if [ "$VERBOSE" = true ]; then
        print_status "Performing repository cleanup..."
        git gc --quiet 2>/dev/null || true
    fi
}

# Main backup function
perform_backup() {
    print_status "Starting backup of: $FOLDER_PATH"
    
    if ! check_changes; then
        # No changes to backup
        if [ "$VERBOSE" = true ]; then
            get_repo_stats
        fi
        return 0
    fi
    
    create_commit
    
    if [ "$REMOTE_AVAILABLE" = true ]; then
        push_to_remote
    fi
    
    cleanup_repo
    
    print_success "Backup completed"
    
    if [ "$VERBOSE" = true ]; then
        get_repo_stats
    fi
}

# Signal handling for graceful shutdown
cleanup_on_exit() {
    if [ $? -ne 0 ]; then
        print_error "Backup failed or was interrupted"
    fi
}

trap cleanup_on_exit EXIT

# Main execution
main() {
    detect_platform
    parse_options "$@"
    validate_inputs
    check_git_health
    
    if [ "$VERBOSE" = true ]; then
        get_repo_stats
    fi
    
    perform_backup
}

# Run main function with all arguments
main "$@"