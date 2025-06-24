#!/bin/bash

# setup-backup.sh - Cross-platform backup setup
# Usage: ./setup-backup.sh <folder_path> <repo_name> [git_remote_url]

set -e  # Exit on any error

# Color output for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
    
    print_status "Detected platform: $PLATFORM"
}

# Check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check for git
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Please install git first."
        case $PLATFORM in
            "Linux"|"WSL")
                echo "  sudo apt install git    # Ubuntu/Debian"
                echo "  sudo yum install git    # RHEL/CentOS"
                ;;
            "macOS")
                echo "  brew install git        # Using Homebrew"
                echo "  xcode-select --install  # Using Xcode tools"
                ;;
        esac
        exit 1
    fi
    
    # Check for file monitoring tools
    case $PLATFORM in
        "Linux"|"WSL")
            if ! command -v inotifywait &> /dev/null; then
                print_warning "inotify-tools not installed. File monitoring won't work."
                echo "  Install with: sudo apt install inotify-tools"
                MONITOR_AVAILABLE=false
            else
                MONITOR_AVAILABLE=true
            fi
            ;;
        "macOS")
            if ! command -v fswatch &> /dev/null; then
                print_warning "fswatch not installed. File monitoring won't work."
                echo "  Install with: brew install fswatch"
                MONITOR_AVAILABLE=false
            else
                MONITOR_AVAILABLE=true
            fi
            ;;
        *)
            print_warning "File monitoring may not be available on $PLATFORM"
            MONITOR_AVAILABLE=false
            ;;
    esac
    
    print_success "Git is available"
}

# Validate inputs
validate_inputs() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi

    if [ $# -lt 2 ]; then
        print_error "Usage: $0 <folder_path> <repo_name> [git_remote_url]"
        echo ""
        echo "Examples:"
        echo "  $0 ~/.config/OrcaSlicer orcaslicer-configs"
        echo "  $0 ~/klipper_config klipper-setup"
        echo "  $0 /path/to/folder my-backup git@github.com:user/repo.git"
        exit 1
    fi
    
    FOLDER_PATH="$1"
    REPO_NAME="$2"
    GIT_REMOTE_URL="$3"
    
    # Expand tilde and resolve path
    FOLDER_PATH=$(eval echo "$FOLDER_PATH")
    FOLDER_PATH=$(realpath "$FOLDER_PATH" 2>/dev/null || echo "$FOLDER_PATH")
    
    # Check if folder exists
    if [ ! -d "$FOLDER_PATH" ]; then
        print_error "Folder does not exist: $FOLDER_PATH"
        exit 1
    fi
    
    # Validate repo name
    if [[ ! "$REPO_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Repository name should only contain letters, numbers, hyphens, and underscores"
        exit 1
    fi
    
    print_success "Input validation passed"
}

# Check if Git is already initialized
check_existing_git() {
    if [ -d "$FOLDER_PATH/.git" ]; then
        print_status "Found existing Git repository in $FOLDER_PATH"
        
        # Check if it has remotes
        cd "$FOLDER_PATH"
        if git remote -v | grep -q .; then
            print_status "Repository already has remote(s):"
            git remote -v
            echo ""
            read -p "Continue with existing setup? (Y/n): " -r
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                print_status "Aborted by user"
                exit 0
            fi
        else
            print_warning "Repository exists but has no remote configured"
            read -p "Add remote to existing repository? (Y/n): " -r
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                print_status "Aborted by user"
                exit 0
            fi
        fi
        return 0
    fi
    return 1
}

# Detect or set the default branch
detect_default_branch() {
    cd "$FOLDER_PATH"
    
    # Check if we're in a repo and get current branch
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local current_branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$current_branch" ]; then
            DEFAULT_BRANCH="$current_branch"
            print_status "Using existing branch: $DEFAULT_BRANCH"
            return 0
        fi
    fi
    
    # Check Git's default branch configuration
    local git_default=$(git config --global init.defaultBranch 2>/dev/null)
    if [ -n "$git_default" ]; then
        DEFAULT_BRANCH="$git_default"
        print_status "Using Git's configured default branch: $DEFAULT_BRANCH"
    else
        # Use 'main' as default (modern standard)
        DEFAULT_BRANCH="main"
        print_status "Using default branch: $DEFAULT_BRANCH"
    fi
}

# Create appropriate .gitignore based on detected files
create_gitignore() {
    print_status "Creating .gitignore file..."
    
    local gitignore_path="$FOLDER_PATH/.gitignore"
    
    # Base ignore patterns
    cat > "$gitignore_path" << 'GITIGNORE_EOF'
# System files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
*~
*.tmp
*.bak
*.swp
*.swo

# Logs
*.log
logs/
*.out

GITIGNORE_EOF

    # Add specific patterns based on detected file types
    if find "$FOLDER_PATH" -name "*.json" -o -name "*.ini" -o -name "*.cfg" | head -1 | grep -q .; then
        print_status "Detected configuration files"
        cat >> "$gitignore_path" << 'GITIGNORE_EOF'
# Keep config files but ignore sensitive data
*password*
*secret*
*key*
*token*
*.pem
*.p12

GITIGNORE_EOF
    fi
    
    if find "$FOLDER_PATH" -name "*.stl" -o -name "*.3mf" | head -1 | grep -q .; then
        print_status "Detected 3D model files"
        cat >> "$gitignore_path" << 'GITIGNORE_EOF'
# Large binary files (uncomment to ignore)
# *.stl
# *.3mf
# *.obj
# *.ply

GITIGNORE_EOF
    fi
    
    if find "$FOLDER_PATH" -name "docker-compose.yml" -o -name "Dockerfile" | head -1 | grep -q .; then
        print_status "Detected Docker files"
        cat >> "$gitignore_path" << 'GITIGNORE_EOF'
# Docker
.env
*.env.local
docker-compose.override.yml
volumes/
data/logs/

GITIGNORE_EOF
    fi
    
    print_success "Created .gitignore with appropriate patterns"
}

# Initialize Git repository
init_git_repo() {
    print_status "Initializing Git repository in $FOLDER_PATH"
    
    cd "$FOLDER_PATH"
    
    # Initialize git with proper default branch
    detect_default_branch
    git init -b "$DEFAULT_BRANCH"
    
    # Create .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        create_gitignore
    fi
    
    # Configure git if not already configured
    if [ -z "$(git config user.name)" ]; then
        print_status "Configuring Git user settings..."
        read -p "Enter your name: " git_name
        read -p "Enter your email: " git_email
        git config user.name "$git_name"
        git config user.email "$git_email"
    fi
    
    # Initial commit
    git add .
    
    # Check if there are files to commit
    if git diff --cached --quiet; then
        print_warning "No files to commit (everything might be ignored)"
        touch "README.md"
        echo "# $REPO_NAME" > "README.md"
        echo "" >> "README.md"
        echo "Automated backup of $FOLDER_PATH" >> "README.md"
        echo "Created on $(date)" >> "README.md"
        git add "README.md"
    fi
    
    git commit -m "Initial backup commit - $(date '+%Y-%m-%d %H:%M:%S')"
    
    print_success "Git repository initialized with branch: $DEFAULT_BRANCH"
}

# Set up remote repository
setup_remote() {
    if [ -n "$GIT_REMOTE_URL" ]; then
        print_status "Setting up remote repository: $GIT_REMOTE_URL"
        git remote add origin "$GIT_REMOTE_URL"
    else
        print_status "Setting up GitHub remote (you'll need to create the repository first)"
        
        # Try to detect GitHub username from SSH config or global git config
        GH_USER=$(git config user.name 2>/dev/null | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        
        if [ -z "$GH_USER" ]; then
            read -p "Enter your GitHub username: " GH_USER
        else
            read -p "GitHub username [$GH_USER]: " input_user
            GH_USER=${input_user:-$GH_USER}
        fi
        
        # Offer SSH and HTTPS options
        echo "Choose remote URL format:"
        echo "1) SSH (recommended): git@github.com:$GH_USER/$REPO_NAME.git"
        echo "2) HTTPS: https://github.com/$GH_USER/$REPO_NAME.git"
        read -p "Choice (1/2): " url_choice
        
        case $url_choice in
            1|"")
                GIT_REMOTE_URL="git@github.com:$GH_USER/$REPO_NAME.git"
                ;;
            2)
                GIT_REMOTE_URL="https://github.com/$GH_USER/$REPO_NAME.git"
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
        
        git remote add origin "$GIT_REMOTE_URL"
    fi
    
    print_success "Remote repository configured: $GIT_REMOTE_URL"
    print_warning "Make sure the repository exists on your Git provider before pushing!"
}

# Test the backup system
test_backup() {
    print_status "Testing backup system..."
    
    # Try to push
    if git push -u origin "$DEFAULT_BRANCH" 2>/dev/null; then
        print_success "Initial push successful!"
    else
        print_warning "Initial push failed. This is normal if the remote repository doesn't exist yet."
        echo "Please:"
        echo "1. Create the repository '$REPO_NAME' on your Git provider"
        echo "2. Run: cd '$FOLDER_PATH' && git push -u origin $DEFAULT_BRANCH"
    fi
}

# Create helper scripts
create_helper_scripts() {
    local script_dir="$(dirname "$0")"
    local backup_script="$script_dir/backup.sh"
    local monitor_script="$script_dir/monitor.sh"
    
    # Create backup script if it doesn't exist
    if [ ! -f "$backup_script" ]; then
        print_status "Creating backup.sh helper script..."
        cat > "$backup_script" << 'SCRIPT_EOF'
#!/bin/bash
# Simple backup script - auto-generated by setup-backup.sh
# Usage: ./backup.sh <folder_path>

FOLDER_PATH="${1:-$(pwd)}"
cd "$FOLDER_PATH"

echo "Checking for changes in $FOLDER_PATH..."

if git status --porcelain | grep .; then
    echo "Changes detected, creating backup..."
    git add .
    git commit -m "Automatic backup $(date '+%Y-%m-%d %H:%M:%S')"
    
    if git push origin "$DEFAULT_BRANCH" 2>/dev/null; then
        echo "✓ Backup completed and pushed successfully"
    else
        echo "✗ Push failed - changes are committed locally"
    fi
else
    echo "No changes to backup"
fi
SCRIPT_EOF
        chmod +x "$backup_script"
    fi
    
    # Create monitor script if monitoring is available
    if [ "$MONITOR_AVAILABLE" = true ] && [ ! -f "$monitor_script" ]; then
        print_status "Creating monitor.sh helper script..."
        
        case $PLATFORM in
            "Linux"|"WSL")
                cat > "$monitor_script" << 'SCRIPT_EOF'
#!/bin/bash
# File monitor script - auto-generated by setup-backup.sh
# Usage: ./monitor.sh <folder_path>

FOLDER_PATH="${1:-$(pwd)}"
SCRIPT_DIR="$(dirname "$0")"

echo "Starting file monitor for $FOLDER_PATH"
echo "Press Ctrl+C to stop"

while true; do
    inotifywait -r -e modify,create,delete,move "$FOLDER_PATH" 2>/dev/null
    echo "Files changed, waiting 10 seconds..."
    sleep 10
    "$SCRIPT_DIR/backup.sh" "$FOLDER_PATH"
done
SCRIPT_EOF
                ;;
            "macOS")
                cat > "$monitor_script" << 'SCRIPT_EOF'
#!/bin/bash
# File monitor script - auto-generated by setup-backup.sh
# Usage: ./monitor.sh <folder_path>

FOLDER_PATH="${1:-$(pwd)}"
SCRIPT_DIR="$(dirname "$0")"

echo "Starting file monitor for $FOLDER_PATH"
echo "Press Ctrl+C to stop"

fswatch -o "$FOLDER_PATH" | while read f; do
    echo "Files changed, waiting 10 seconds..."
    sleep 10
    "$SCRIPT_DIR/backup.sh" "$FOLDER_PATH"
done
SCRIPT_EOF
                ;;
        esac
        
        chmod +x "$monitor_script"
    fi
}

# Main execution
main() {
    echo "============================================"
    echo "  SafeSync - Simple Backup System Setup"
    echo "============================================"
    echo ""
    
    detect_platform
    check_dependencies
    validate_inputs "$@"
    
    cd "$FOLDER_PATH"
    
    if check_existing_git; then
        print_status "Working with existing Git repository"
        detect_default_branch
        
        # Add .gitignore if it doesn't exist
        if [ ! -f ".gitignore" ]; then
            create_gitignore
        fi
    else
        init_git_repo
    fi
    
    setup_remote
    test_backup
    create_helper_scripts
    
    echo ""
    echo "============================================"
    print_success "Setup completed successfully!"
    echo "============================================"
    echo ""
    echo "Next steps:"
    echo "1. Manual backup: $(dirname "$0")/backup.sh '$FOLDER_PATH'"
    
    if [ "$MONITOR_AVAILABLE" = true ]; then
        echo "2. Start monitoring: $(dirname "$0")/monitor.sh '$FOLDER_PATH' &"
    fi
    
    echo "3. Add to cron for scheduled backups:"
    echo "   crontab -e"
    echo "   # Add: 0 */4 * * * $(dirname "$0")/backup.sh '$FOLDER_PATH'"
    echo ""
    echo "Repository: $GIT_REMOTE_URL"
    echo "Local path: $FOLDER_PATH"
}

# Run main function with all arguments
main "$@"
