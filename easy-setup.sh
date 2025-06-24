#!/bin/bash

# easy-setup.sh - Simple SafeSync setup wizard
# Usage: ./easy-setup.sh

set -e  # Exit on any error

# Color output for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global variables
PLATFORM=""
FOUND_CONFIGS=()
GITHUB_USERNAME=""

# Function to print colored output
print_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}SafeSync Setup Wizard${NC} - Keep Your Configs Safe Forever  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  🎯 Point SafeSync at any folder → It stays backed up forever"
    echo ""
    echo -e "  ${YELLOW}� GitHub Account Required${NC}"
    echo "  SafeSync backs up your files to GitHub repositories for safety."
    echo "  A free GitHub account is required for this system to work."
    echo ""
    echo -e "  ${BLUE}�📋 Quick Requirements Check:${NC}"
    echo "    • ✓ Git installed on your system"
    echo "    • ✓ Free GitHub account (we'll help if you don't have one)"
    echo "    • ✓ SSH key setup (we'll create and configure this for you)"
    echo ""
}

print_step() {
    echo -e "${BOLD}${BLUE}Step $1:${NC} $2"
    echo ""
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC}  $1"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_found() {
    echo -e "  ${GREEN}📁${NC} $1"
}

# Simple yes/no prompt
ask_yes_no() {
    local question="$1"
    local default="${2:-y}"
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "$question (Y/n): " response
            response=${response:-y}
        else
            read -p "$question (y/N): " response
            response=${response:-n}
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Wait for user to press Enter
press_enter() {
    local message="${1:-Press Enter to continue...}"
    echo ""
    read -p "$message"
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
        *)          PLATFORM="Linux";;  # Default fallback
    esac
}

# Get GitHub username and validate
get_github_username() {
    echo ""
    print_step "1" "GitHub Account Setup"
    echo "  SafeSync backs up your configs to GitHub repositories."
    echo "  This keeps them safe and accessible from anywhere."
    echo ""
    
    # Check if user has a GitHub account
    if ! ask_yes_no "Do you have a GitHub account?"; then
        echo ""
        print_info "You'll need a free GitHub account to use SafeSync."
        echo ""
        echo "  1. Go to: https://github.com/join"
        echo "  2. Create your free account"
        echo "  3. Come back and run this script again"
        echo ""
        exit 0
    fi
    
    # Try to detect existing Git username
    local git_user=""
    if command -v git >/dev/null 2>&1; then
        git_user=$(git config --global user.name 2>/dev/null | tr ' ' '-' | tr '[:upper:]' '[:lower:]' 2>/dev/null || echo "")
    fi
    
    while true; do
        if [ -n "$git_user" ]; then
            read -p "Enter your GitHub username [$git_user]: " GITHUB_USERNAME
            GITHUB_USERNAME=${GITHUB_USERNAME:-$git_user}
        else
            read -p "Enter your GitHub username: " GITHUB_USERNAME
        fi
        
        if [ -z "$GITHUB_USERNAME" ]; then
            print_error "GitHub username is required"
            continue
        fi
        
        # Basic validation
        if [[ ! "$GITHUB_USERNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]] && [[ ! "$GITHUB_USERNAME" =~ ^[a-zA-Z0-9]$ ]]; then
            print_warning "GitHub usernames can only contain alphanumeric characters and hyphens"
            continue
        fi
        
        break
    done
    
    print_success "Using GitHub username: $GITHUB_USERNAME"
}

# Setup SSH key for GitHub authentication
setup_ssh_key() {
    print_info "Setting up secure connection to GitHub..."
    
    local ssh_key_path=""
    local ssh_key_type=""
    
    # Check for existing SSH keys
    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        ssh_key_path="$HOME/.ssh/id_ed25519.pub"
        ssh_key_type="ed25519"
        print_success "Found existing SSH key (ed25519)"
    elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        ssh_key_path="$HOME/.ssh/id_rsa.pub"
        ssh_key_type="rsa"
        print_success "Found existing SSH key (rsa)"
    else
        print_warning "No SSH key found"
        echo ""
        echo "  SSH keys let you securely connect to GitHub without passwords."
        echo "  We'll create one for you - it's quick and safe!"
        echo ""
        
        if ask_yes_no "Create an SSH key now?"; then
            create_ssh_key
            ssh_key_path="$HOME/.ssh/id_ed25519.pub"
            ssh_key_type="ed25519"
        else
            print_error "SSH key is required for SafeSync to work with GitHub"
            echo ""
            echo "  You can create one manually later:"
            echo "    ssh-keygen -t ed25519 -C \"your-email@example.com\""
            echo ""
            exit 1
        fi
    fi
    
    # Test SSH connection to GitHub
    print_info "Testing connection to GitHub..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_success "GitHub connection working perfectly!"
    else
        print_warning "SSH key needs to be added to GitHub"
        guide_ssh_key_upload "$ssh_key_path"
    fi
}

# Create a new SSH key
create_ssh_key() {
    print_info "Creating your SSH key..."
    
    # Get user's email for the SSH key
    local email=""
    if command -v git >/dev/null 2>&1; then
        email=$(git config --global user.email 2>/dev/null || echo "")
    fi
    
    if [ -z "$email" ]; then
        read -p "Enter your email address: " email
        if [ -z "$email" ]; then
            email="user@example.com"
            print_info "Using placeholder email: $email"
        fi
    fi
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Generate the SSH key
    echo ""
    print_info "Generating SSH key (this may take a moment)..."
    
    if ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1; then
        print_success "SSH key created successfully!"
        chmod 600 "$HOME/.ssh/id_ed25519"
        chmod 644 "$HOME/.ssh/id_ed25519.pub"
    else
        print_error "Failed to create SSH key"
        echo "You may need to create one manually later."
        exit 1
    fi
}

# Guide user through adding SSH key to GitHub
guide_ssh_key_upload() {
    local key_path="$1"
    
    echo ""
    print_step "SSH" "Add Your Key to GitHub"
    echo "  We need to add your SSH key to your GitHub account."
    echo "  This is a one-time setup that keeps your backups secure."
    echo ""
    
    # Copy key to clipboard if possible
    local key_content=$(cat "$key_path")
    if command -v pbcopy >/dev/null 2>&1; then
        # macOS
        echo "$key_content" | pbcopy
        print_success "SSH key copied to clipboard!"
    elif command -v xclip >/dev/null 2>&1; then
        # Linux with xclip
        echo "$key_content" | xclip -selection clipboard
        print_success "SSH key copied to clipboard!"
    elif command -v xsel >/dev/null 2>&1; then
        # Linux with xsel
        echo "$key_content" | xsel --clipboard --input
        print_success "SSH key copied to clipboard!"
    elif [ -n "$WSL_DISTRO_NAME" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL - try to copy to Windows clipboard
        if command -v clip.exe >/dev/null 2>&1; then
            echo "$key_content" | clip.exe
            print_success "SSH key copied to Windows clipboard!"
        else
            print_info "Couldn't auto-copy key - you'll need to copy it manually"
        fi
    else
        print_info "Couldn't auto-copy key - you'll need to copy it manually"
    fi
    
    echo ""
    echo "  Follow these steps:"
    echo ""
    echo "  1. 🌐 Open GitHub in your browser:"
    echo "     https://github.com/settings/ssh/new"
    echo ""
    echo "  2. 📝 Fill in the form:"
    echo "     • Title: SafeSync Key (or any name you like)"
    echo "     • Key: Paste your key (see below if not auto-copied)"
    echo ""
    echo "  3. ✅ Click 'Add SSH key'"
    echo ""
    
    if [ -z "$(command -v pbcopy)" ] && [ -z "$(command -v xclip)" ] && [ -z "$(command -v xsel)" ] && [ -z "$(command -v clip.exe)" ]; then
        echo "  📋 Your SSH key (copy this):"
        echo "  ┌─────────────────────────────────────────────────────────────────┐"
        echo "  │ $key_content"
        echo "  └─────────────────────────────────────────────────────────────────┘"
        echo ""
    fi
    
    press_enter "Press Enter after you've added the key to GitHub..."
    
    # Test the connection again
    print_info "Testing GitHub connection..."
    local attempts=0
    while [ $attempts -lt 3 ]; do
        if ssh -o ConnectTimeout=10 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            print_success "Perfect! GitHub connection is working! 🎉"
            return 0
        fi
        
        ((attempts++))
        if [ $attempts -lt 3 ]; then
            print_warning "Connection not working yet..."
            if ask_yes_no "Try again? (Make sure you clicked 'Add SSH key')"; then
                continue
            else
                break
            fi
        fi
    done
    
    print_error "GitHub connection still not working"
    echo ""
    echo "  Don't worry! You can continue setup and fix this later."
    echo "  The repositories will be created, but you may need to push manually."
    echo ""
    echo "  Troubleshooting:"
    echo "  • Make sure you clicked 'Add SSH key' on GitHub"
    echo "  • Try: ssh -T git@github.com"
    echo "  • GitHub SSH help: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
    echo ""
    
    if ! ask_yes_no "Continue with setup?"; then
        echo "Fix the SSH connection and run the script again."
        exit 1
    fi
}

# Check if a GitHub repository exists
check_repo_exists() {
    local repo_name="$1"
    local repo_url="https://github.com/$GITHUB_USERNAME/$repo_name"
    
    # Try to check if the repository exists (this is a simple check)
    if curl -s -o /dev/null -w "%{http_code}" "$repo_url" 2>/dev/null | grep -q "200"; then
        return 0  # Repository exists
    else
        return 1  # Repository doesn't exist or can't access
    fi
}

# Find common 3D printing software configs
find_common_configs() {
    FOUND_CONFIGS=()
    
    # OrcaSlicer locations
    case $PLATFORM in
        "WSL")
            # Check Windows locations from WSL
            for user_dir in /mnt/c/Users/*/; do
                if [ -d "${user_dir}AppData/Roaming/OrcaSlicer/user/default" ]; then
                    FOUND_CONFIGS+=("${user_dir}AppData/Roaming/OrcaSlicer/user/default|OrcaSlicer (Windows - $(basename "$user_dir"))")
                fi
            done
            # Check Linux location in WSL
            if [ -d "$HOME/.config/OrcaSlicer" ]; then
                FOUND_CONFIGS+=("$HOME/.config/OrcaSlicer|OrcaSlicer (Linux)")
            fi
            ;;
        "Linux")
            if [ -d "$HOME/.config/OrcaSlicer" ]; then
                FOUND_CONFIGS+=("$HOME/.config/OrcaSlicer|OrcaSlicer")
            fi
            ;;
        "macOS")
            if [ -d "$HOME/Library/Application Support/OrcaSlicer" ]; then
                FOUND_CONFIGS+=("$HOME/Library/Application Support/OrcaSlicer|OrcaSlicer")
            fi
            ;;
    esac
    
    # PrusaSlicer locations
    case $PLATFORM in
        "WSL")
            for user_dir in /mnt/c/Users/*/; do
                if [ -d "${user_dir}AppData/Roaming/PrusaSlicer" ]; then
                    FOUND_CONFIGS+=("${user_dir}AppData/Roaming/PrusaSlicer|PrusaSlicer (Windows - $(basename "$user_dir"))")
                fi
            done
            if [ -d "$HOME/.config/PrusaSlicer" ]; then
                FOUND_CONFIGS+=("$HOME/.config/PrusaSlicer|PrusaSlicer (Linux)")
            fi
            ;;
        "Linux")
            if [ -d "$HOME/.config/PrusaSlicer" ]; then
                FOUND_CONFIGS+=("$HOME/.config/PrusaSlicer|PrusaSlicer")
            fi
            ;;
        "macOS")
            if [ -d "$HOME/Library/Application Support/PrusaSlicer" ]; then
                FOUND_CONFIGS+=("$HOME/Library/Application Support/PrusaSlicer|PrusaSlicer")
            fi
            ;;
    esac
    
    # Klipper locations
    local klipper_dirs=(
        "$HOME/klipper_config"
        "$HOME/printer_data/config"
        "/home/pi/klipper_config"
        "/home/pi/printer_data/config"
    )
    
    for dir in "${klipper_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local name="Klipper Config"
            if [[ "$dir" == *"printer_data"* ]]; then
                name="Klipper (Mainsail/Fluidd)"
            fi
            FOUND_CONFIGS+=("$dir|$name")
        fi
    done
}

# Simple wizard flow
run_wizard() {
    print_banner
    
    # First, get GitHub username
    get_github_username
    
    print_step "2" "Finding Your Config Folders"
    find_common_configs
    
    if [ ${#FOUND_CONFIGS[@]} -gt 0 ]; then
        print_success "Found some config folders!"
        echo ""
        
        local index=1
        for config in "${FOUND_CONFIGS[@]}"; do
            IFS='|' read -r path name <<< "$config"
            print_found "[$index] $name"
            echo "      📂 $path"
            ((index++))
        done
        
        echo ""
        if ask_yes_no "Set up backup for these folders?"; then
            setup_found_configs
        else
            setup_custom_folder
        fi
    else
        print_info "No common 3D printing configs found automatically."
        echo ""
        setup_custom_folder
    fi
    
    print_step "3" "All Done!"
    print_success "SafeSync is now protecting your configs!"
    echo ""
    echo "  What happens next:"
    echo "  • Your files are automatically tracked in Git"
    echo "  • Every change gets backed up to your remote repository"
    echo "  • You can set up monitoring and scheduled backups"
    echo ""
    echo "  Useful commands:"
    echo "  • Manual backup:     ./backup.sh [folder]"
    echo "  • Start monitoring:  ./monitor.sh [folder] &"
    echo "  • Schedule backups:  ./install-cron.sh [folder]"
    echo ""
    print_success "Your configs are now safe! 🎉"
}

# Set up the configs we found
setup_found_configs() {
    echo ""
    for config in "${FOUND_CONFIGS[@]}"; do
        IFS='|' read -r path name <<< "$config"
        
        print_info "Setting up: $name"
        
        # Generate repo name from the config name
        local repo_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
        repo_name="${repo_name}-configs"
        
        # Check if repository already exists
        if check_repo_exists "$repo_name"; then
            print_warning "Repository '$repo_name' already exists on GitHub"
            if ask_yes_no "Use existing repository?"; then
                print_info "Will connect to existing repository"
            else
                # Generate alternative name
                local counter=2
                local alt_name="${repo_name}-${counter}"
                while check_repo_exists "$alt_name"; do
                    ((counter++))
                    alt_name="${repo_name}-${counter}"
                done
                repo_name="$alt_name"
                print_info "Using alternative name: $repo_name"
            fi
        fi
        
        # Generate the GitHub URL
        local github_url="git@github.com:$GITHUB_USERNAME/$repo_name.git"
        
        if "$SCRIPT_DIR/setup-backup.sh" "$path" "$repo_name" "$github_url"; then
            print_success "✓ $name backed up successfully"
            echo "      🔗 Repository: https://github.com/$GITHUB_USERNAME/$repo_name"
        else
            print_error "✗ Failed to set up $name"
        fi
        echo ""
    done
}

# Set up a custom folder
setup_custom_folder() {
    print_step "2" "Custom Folder Setup"
    echo "  Let's set up backup for a folder you choose."
    echo ""
    
    while true; do
        read -p "Enter the full path to your folder: " folder_path
        
        if [ -z "$folder_path" ]; then
            print_error "Please enter a folder path"
            continue
        fi
        
        if [ ! -d "$folder_path" ]; then
            print_error "Folder doesn't exist: $folder_path"
            if ! ask_yes_no "Try a different path?"; then
                exit 1
            fi
            continue
        fi
        
        break
    done
    
    echo ""
    read -p "Enter a name for your backup repository: " repo_name
    
    if [ -z "$repo_name" ]; then
        repo_name="my-configs"
        print_info "Using default name: $repo_name"
    fi
    
    # Clean up repository name
    repo_name=$(echo "$repo_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    
    # Check if repository already exists
    if check_repo_exists "$repo_name"; then
        print_warning "Repository '$repo_name' already exists on GitHub"
        if ask_yes_no "Use existing repository?"; then
            print_info "Will connect to existing repository"
        else
            # Generate alternative name
            local counter=2
            local alt_name="${repo_name}-${counter}"
            while check_repo_exists "$alt_name"; do
                ((counter++))
                alt_name="${repo_name}-${counter}"
            done
            repo_name="$alt_name"
            print_info "Using alternative name: $repo_name"
        fi
    fi
    
    echo ""
    print_info "Setting up backup for: $folder_path"
    print_info "Repository name: $repo_name"
    
    # Generate the GitHub URL
    local github_url="git@github.com:$GITHUB_USERNAME/$repo_name.git"
    
    if "$SCRIPT_DIR/setup-backup.sh" "$folder_path" "$repo_name" "$github_url"; then
        print_success "Backup setup completed!"
        echo "  🔗 Repository: https://github.com/$GITHUB_USERNAME/$repo_name"
    else
        print_error "Setup failed"  
        exit 1
    fi
}

# Main execution
main() {
    # Handle help argument
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "SafeSync Easy Setup - Simple backup wizard for your important configs"
        echo ""
        echo "Usage: $0"
        echo ""
        echo "This script will guide you through setting up SafeSync to backup"
        echo "your important configuration folders automatically."
        echo ""
        echo "What it does:"
        echo "• Detects common 3D printing software configs (OrcaSlicer, PrusaSlicer, Klipper)"
        echo "• Sets up your GitHub account and SSH keys automatically"
        echo "• Creates remote repositories and configures Git backup"
        echo "• Guides you through the entire process step-by-step"
        echo ""
        echo "Requirements:"
        echo "• Free GitHub account (we'll help you sign up if needed)"
        echo "• Git installed on your system"
        echo ""
        echo "Just run: $0"
        echo ""
        exit 0
    fi
    
    # Check if core setup script exists
    if [ ! -f "$SCRIPT_DIR/setup-backup.sh" ]; then
        print_error "Core setup script not found: $SCRIPT_DIR/setup-backup.sh"
        echo "Make sure you're running this from the SafeSync directory"
        exit 1
    fi
    
    # Make sure setup script is executable
    chmod +x "$SCRIPT_DIR"/setup-backup.sh "$SCRIPT_DIR"/backup.sh "$SCRIPT_DIR"/monitor.sh "$SCRIPT_DIR"/install-cron.sh 2>/dev/null || true
    
    # Detect platform
    detect_platform
    
    # Run the simple wizard
    run_wizard
}

# Run main function
main "$@"
