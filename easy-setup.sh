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
    echo -e "  ${YELLOW}📋 What This Wizard Does:${NC}"
    echo "    1. Check and install required system tools"
    echo "    2. Set up secure GitHub connection (SSH keys)"
    echo "    3. Find your 3D printing configs automatically"
    echo "    4. Create backup repositories and start protecting your files"
    echo ""
    echo -e "  ${BLUE}� Requirements:${NC}"
    echo "    • Free GitHub account (sign up at github.com if needed)"
    echo "    • Administrator/sudo access (for installing tools)"
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

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect package manager
detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists brew; then
        echo "brew"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Install a package based on the detected package manager
install_package() {
    local package="$1"
    local pm=$(detect_package_manager)
    
    print_info "Installing $package..."
    
    case $pm in
        "apt")
            if sudo apt-get update && sudo apt-get install -y "$package"; then
                return 0
            fi
            ;;
        "yum")
            if sudo yum install -y "$package"; then
                return 0
            fi
            ;;
        "dnf")
            if sudo dnf install -y "$package"; then
                return 0
            fi
            ;;
        "pacman")
            if sudo pacman -S --noconfirm "$package"; then
                return 0
            fi
            ;;
        "brew")
            if brew install "$package"; then
                return 0
            fi
            ;;
        "zypper")
            if sudo zypper install -y "$package"; then
                return 0
            fi
            ;;
        *)
            print_error "Unknown package manager. Please install $package manually."
            return 1
            ;;
    esac
    
    print_error "Failed to install $package"
    return 1
}

# Check and install Git
check_and_install_git() {
    if command_exists git; then
        print_success "Git is already installed"
        return 0
    fi
    
    print_warning "Git is not installed"
    echo ""
    echo "  Git is required for SafeSync to backup your files."
    echo "  It's the industry standard for version control."
    echo ""
    
    if ask_yes_no "Install Git now?"; then
        if install_package git; then
            print_success "Git installed successfully!"
            return 0
        else
            print_error "Failed to install Git"
            echo ""
            echo "  Please install Git manually:"
            case $(detect_package_manager) in
                "apt") echo "    sudo apt-get install git" ;;
                "yum") echo "    sudo yum install git" ;;
                "dnf") echo "    sudo dnf install git" ;;
                "pacman") echo "    sudo pacman -S git" ;;
                "brew") echo "    brew install git" ;;
                "zypper") echo "    sudo zypper install git" ;;
                *) echo "    Use your system's package manager to install git" ;;
            esac
            echo ""
            return 1
        fi
    else
        print_error "Git is required for SafeSync to work"
        echo "Please install Git and run this script again."
        return 1
    fi
}

# Check and install file monitoring tools
check_and_install_monitor_tools() {
    local tool_needed=""
    local install_cmd=""
    
    case $PLATFORM in
        "Linux"|"WSL")
            if command_exists inotifywait; then
                print_success "inotify-tools is already installed"
                return 0
            fi
            tool_needed="inotify-tools"
            ;;
        "macOS")
            if command_exists fswatch; then
                print_success "fswatch is already installed"
                return 0
            fi
            tool_needed="fswatch"
            ;;
        *)
            print_info "File monitoring tools not checked for this platform"
            return 0
            ;;
    esac
    
    print_warning "$tool_needed is not installed"
    echo ""
    echo "  $tool_needed enables real-time file monitoring."
    echo "  While not strictly required, it's highly recommended for automatic backups."
    echo ""
    
    if ask_yes_no "Install $tool_needed now?" "y"; then
        if install_package "$tool_needed"; then
            print_success "$tool_needed installed successfully!"
            return 0
        else
            print_warning "Failed to install $tool_needed"
            echo ""
            echo "  You can install it manually later:"
            case $(detect_package_manager) in
                "apt") echo "    sudo apt-get install $tool_needed" ;;
                "yum") echo "    sudo yum install $tool_needed" ;;
                "dnf") echo "    sudo dnf install $tool_needed" ;;
                "pacman") 
                    if [ "$tool_needed" = "inotify-tools" ]; then
                        echo "    sudo pacman -S inotify-tools"
                    else
                        echo "    sudo pacman -S $tool_needed"
                    fi
                    ;;
                "brew") echo "    brew install $tool_needed" ;;
                "zypper") echo "    sudo zypper install $tool_needed" ;;
                *) echo "    Use your system's package manager to install $tool_needed" ;;
            esac
            echo ""
            echo "  SafeSync will still work without it, but monitoring will be manual."
            return 0
        fi
    else
        print_info "Skipping $tool_needed installation"
        echo "  You can enable real-time monitoring later by installing $tool_needed"
        return 0
    fi
}

# Check and install GitHub CLI
check_and_install_github_cli() {
    if command_exists gh; then
        print_success "GitHub CLI is already installed"
        return 0
    fi
    
    print_info "GitHub CLI not found"
    echo ""
    echo "  GitHub CLI enables automatic repository creation, making setup even easier."
    echo "  Without it, you'll need to create repositories manually on GitHub."
    echo ""
    
    if ask_yes_no "Install GitHub CLI for automatic repository creation?" "y"; then
        local pm=$(detect_package_manager)
        local install_cmd=""
        
        case $pm in
            "apt")
                # GitHub CLI installation for Ubuntu/Debian
                if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null 2>&1 && \
                   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null && \
                   sudo apt update >/dev/null 2>&1 && \
                   sudo apt install -y gh >/dev/null 2>&1; then
                    print_success "GitHub CLI installed successfully!"
                    return 0
                else
                    print_warning "Failed to install GitHub CLI automatically"
                fi
                ;;
            "brew")
                if brew install gh >/dev/null 2>&1; then
                    print_success "GitHub CLI installed successfully!"
                    return 0
                else
                    print_warning "Failed to install GitHub CLI with Homebrew"
                fi
                ;;
            "yum"|"dnf")
                if sudo $pm install -y gh >/dev/null 2>&1; then
                    print_success "GitHub CLI installed successfully!"
                    return 0
                else
                    print_warning "Failed to install GitHub CLI with $pm"
                fi
                ;;
            *)
                print_warning "Automatic installation not supported for this package manager"
                ;;
        esac
        
        echo ""
        echo "  Manual installation instructions:"
        echo "  • Visit: https://cli.github.com/manual/installation"
        case $pm in
            "apt") echo "  • Or try: curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg" ;;
            "brew") echo "  • Or try: brew install gh" ;;
            "yum"|"dnf") echo "  • Or try: sudo $pm install gh" ;;
            "pacman") echo "  • Or try: sudo pacman -S github-cli" ;;
        esac
        echo ""
        return 1
    else
        print_info "Skipping GitHub CLI installation"
        echo "  You can install it later for easier repository management:"
        echo "  • Visit: https://cli.github.com/"
        return 0
    fi
}

# Check all system requirements
check_system_requirements() {
    print_step "1" "Checking System Requirements"
    
    local git_ok=false
    local monitor_ok=false
    
    # Check Git
    if check_and_install_git; then
        git_ok=true
    fi
    
    # Check monitoring tools
    if check_and_install_monitor_tools; then
        monitor_ok=true
    fi
    
    # Check GitHub CLI
    if check_and_install_github_cli; then
        github_cli_ok=true
    fi
    
    echo ""
    if [ "$git_ok" = true ]; then
        print_success "System requirements satisfied!"
        echo ""
        return 0
    else
        print_error "Required dependencies missing"
        echo "Please install missing requirements and run this script again."
        return 1
    fi
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

# Install Git
install_git() {
    print_info "Installing Git..."
    
    case $PLATFORM in
        "Linux"|"WSL")
            if command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y git
            elif command -v yum >/dev/null 2>&1; then
                sudo yum install -y git
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y git
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm git
            else
                print_error "Cannot auto-install Git on this system"
                echo "Please install Git manually and run this script again."
                exit 1
            fi
            ;;
        "macOS")
            if command -v brew >/dev/null 2>&1; then
                brew install git
            else
                print_error "Homebrew not found"
                echo "Please install Git manually:"
                echo "1. Install Xcode Command Line Tools: xcode-select --install"
                echo "2. Or install Homebrew and run: brew install git"
                exit 1
            fi
            ;;
    esac
    
    if command -v git >/dev/null 2>&1; then
        print_success "Git installed successfully!"
    else
        print_error "Git installation failed"
        exit 1
    fi
}

# Install inotify-tools for Linux/WSL
install_inotify_tools() {
    print_info "Installing inotify-tools..."
    
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y inotify-tools
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y inotify-tools
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y inotify-tools
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm inotify-tools
    else
        print_warning "Cannot auto-install inotify-tools on this system"
        echo "Please install it manually: sudo apt install inotify-tools"
        return 1
    fi
    
    if command -v inotifywait >/dev/null 2>&1; then
        print_success "inotify-tools installed successfully!"
    else
        print_warning "inotify-tools installation may have failed"
    fi
}

# Install fswatch for macOS
install_fswatch() {
    print_info "Installing fswatch..."
    
    if command -v brew >/dev/null 2>&1; then
        brew install fswatch
    else
        print_error "Homebrew not found"
        echo "Please install Homebrew first: https://brew.sh"
        echo "Then run: brew install fswatch"
        return 1
    fi
    
    if command -v fswatch >/dev/null 2>&1; then
        print_success "fswatch installed successfully!"
    else
        print_warning "fswatch installation may have failed"
    fi
}

# Get GitHub username and validate
get_github_username() {
    echo ""
    print_step "3" "GitHub Account Setup"
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
    print_step "2" "Setting Up GitHub Connection"
    print_info "Checking secure connection to GitHub..."
    
    # First, test if GitHub connection already works
    print_info "Testing existing GitHub connection..."
    if ssh -o ConnectTimeout=10 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_success "GitHub connection is already working perfectly! ✨"
        
        # Try to identify which key/method is being used
        if [ -f "$HOME/.ssh/config" ] && grep -q "IdentityAgent.*1password" "$HOME/.ssh/config"; then
            print_info "🔐 Using 1Password SSH agent - excellent security choice!"
        elif ssh-add -l >/dev/null 2>&1 && ssh-add -l | grep -q "."; then
            print_info "🔑 Using SSH agent with loaded keys"
        else
            print_info "🗂️ Using SSH key files from ~/.ssh/"
        fi
        
        echo ""
        return 0
    fi
    
    # If connection failed, do comprehensive key detection
    print_warning "GitHub connection not working yet. Let's fix that..."
    
    local ssh_key_path=""
    local ssh_key_type=""
    local found_keys=()
    
    # Look for all .pub files in .ssh directory
    if [ -d "$HOME/.ssh" ]; then
        while IFS= read -r -d '' pubkey; do
            if [ -f "$pubkey" ] && [ -f "${pubkey%.pub}" ]; then
                # Check if the private key exists and is readable
                if [ -r "${pubkey%.pub}" ]; then
                    found_keys+=("$pubkey")
                fi
            fi
        done < <(find "$HOME/.ssh" -name "*.pub" -print0 2>/dev/null)
    fi
    
    if [ ${#found_keys[@]} -gt 0 ]; then
        # Use the first available key
        ssh_key_path="${found_keys[0]}"
        local key_name=$(basename "$ssh_key_path" .pub)
        
        # Determine key type from the key content
        if grep -q "ssh-ed25519" "$ssh_key_path" 2>/dev/null; then
            ssh_key_type="ed25519"
        elif grep -q "ssh-rsa" "$ssh_key_path" 2>/dev/null; then
            ssh_key_type="rsa"
        elif grep -q "ecdsa-" "$ssh_key_path" 2>/dev/null; then
            ssh_key_type="ecdsa"
        else
            ssh_key_type="unknown"
        fi
        
        print_success "Found SSH key: $key_name ($ssh_key_type)"
        
        # If multiple keys found, show them
        if [ ${#found_keys[@]} -gt 1 ]; then
            print_info "Multiple SSH keys available:"
            for key in "${found_keys[@]}"; do
                local name=$(basename "$key" .pub)
                local type="unknown"
                if grep -q "ssh-ed25519" "$key" 2>/dev/null; then
                    type="ed25519"
                elif grep -q "ssh-rsa" "$key" 2>/dev/null; then
                    type="rsa"
                elif grep -q "ecdsa-" "$key" 2>/dev/null; then
                    type="ecdsa"
                fi
                echo "      • $name ($type)"
            done
            echo "      Using: $key_name for GitHub setup"
        fi
        
        echo ""
        print_info "SSH key found but GitHub connection not working."
        print_info "This might be because:"
        echo "  • Key not added to your GitHub account yet"
        echo "  • SSH agent not running or key not loaded"
        echo "  • Using 1Password but SSH agent not configured"
        echo ""
        
        guide_ssh_key_upload "$ssh_key_path"
    else
        print_warning "No SSH key files found"
        echo ""
        echo "  SSH keys let you securely connect to GitHub without passwords."
        echo "  We can:"
        echo "  • Create a new SSH key for you (traditional method)"
        echo "  • Help you set up 1Password SSH agent (more secure)"
        echo ""
        
        if ask_yes_no "Create a new SSH key now?"; then
            create_ssh_key
            ssh_key_path="$HOME/.ssh/id_ed25519.pub"
            ssh_key_type="ed25519"
            guide_ssh_key_upload "$ssh_key_path"
        else
            print_error "SSH authentication is required for SafeSync to work with GitHub"
            echo ""
            echo "  Manual setup options:"
            echo "  • Create SSH key: ssh-keygen -t ed25519 -C \"your-email@example.com\""
            echo "  • 1Password SSH: https://developer.1password.com/docs/ssh/"
            echo "  • GitHub SSH help: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
            echo ""
            exit 1
        fi
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
    
    # Try to check if the repository exists
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$repo_url" 2>/dev/null)
    if [ "$http_code" = "200" ]; then
        return 0  # Repository exists
    else
        return 1  # Repository doesn't exist or can't access
    fi
}

# Helper function to create GitHub repository (requires GitHub CLI)
create_github_repo() {
    local repo_name="$1"
    
    # Check if GitHub CLI is available
    if ! command_exists gh; then
        return 1  # GitHub CLI not available
    fi
    
    # Check if user is authenticated
    if ! gh auth status >/dev/null 2>&1; then
        print_info "GitHub CLI found but not authenticated."
        echo ""
        if ask_yes_no "Authenticate with GitHub now?"; then
            print_info "Starting GitHub authentication..."
            echo ""
            echo "  Please follow the instructions to authenticate:"
            echo ""
            if gh auth login; then
                print_success "GitHub authentication successful!"
            else
                print_warning "GitHub authentication failed"
                return 1
            fi
        else
            print_info "Skipping GitHub authentication"
            return 1
        fi
    fi
    
    print_info "Creating GitHub repository '$repo_name'..."
    if gh repo create "$repo_name" --public --description "SafeSync backup for $repo_name" >/dev/null 2>&1; then
        print_success "Repository '$repo_name' created successfully!"
        return 0
    else
        print_warning "Failed to create repository with GitHub CLI"
        echo "  This might be because:"
        echo "  • Repository name already exists"
        echo "  • Network connection issues"
        echo "  • GitHub API limits"
        return 1
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
    
    # Check system requirements first
    if ! check_system_requirements; then
        exit 1
    fi
    
    # Set up SSH connection to GitHub
    setup_ssh_key
    
    # Get GitHub username
    get_github_username
    
    print_step "4" "Finding Your Config Folders"
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
    
    print_step "5" "Setup Complete!"
    print_success "SafeSync is configured and ready to protect your configs!"
    echo ""
    echo "  📋 Important: Complete the setup by creating your GitHub repositories"
    echo "     The script showed you the GitHub links and commands above."
    echo ""
    echo "  ⚡ Once repositories are created:"
    echo "  • Your files are automatically tracked in Git"
    echo "  • Every change gets backed up to your remote repository" 
    echo "  • You can set up monitoring and scheduled backups"
    echo ""
    echo "  🛠️ Useful commands:"
    echo "  • Manual backup:     ./backup.sh [folder]"
    echo "  • Start monitoring:  ./monitor.sh [folder] &"
    echo "  • Schedule backups:  ./install-cron.sh [folder]"
    echo ""
    print_success "Your configs will be safe once you create the repositories! 🎉"
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
        else
            # Repository doesn't exist, offer to create it
            if command -v gh >/dev/null 2>&1; then
                echo ""
                print_info "Repository '$repo_name' doesn't exist yet."
                if ask_yes_no "Create repository automatically with GitHub CLI?"; then
                    if create_github_repo "$repo_name"; then
                        print_success "Repository created! Setup will continue..."
                    else
                        print_info "Automatic creation failed. You'll need to create it manually."
                    fi
                else
                    print_info "You'll need to create the repository manually on GitHub."
                fi
            else
                print_info "Repository '$repo_name' will need to be created manually on GitHub."
            fi
        fi
        
        # Generate the GitHub URL
        local github_url="git@github.com:$GITHUB_USERNAME/$repo_name.git"
        
        if "$SCRIPT_DIR/setup-backup.sh" "$path" "$repo_name" "$github_url"; then
            print_success "✓ $name configured for backup"
            echo "      🔗 Repository URL: https://github.com/$GITHUB_USERNAME/$repo_name"
            echo ""
            # Only show manual steps if the repository wasn't created automatically
            if ! check_repo_exists "$repo_name"; then
                print_info "📋 Next steps for $name:"
                echo "      1. Create the repository '$repo_name' on GitHub:"
                echo "         https://github.com/new"
                echo "      2. Push your first backup:"
                echo "         cd '$path' && git push -u origin main"
            else
                print_info "✅ Repository exists! You can now push your first backup:"
                echo "         cd '$path' && git push -u origin main"
            fi
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
        echo "• Checks and installs required system tools (Git, inotify-tools/fswatch)"
        echo "• Creates SSH keys and sets up secure GitHub connection"
        echo "• Detects common 3D printing software configs (OrcaSlicer, PrusaSlicer, Klipper)"
        echo "• Configures Git repositories and prepares remote repository setup"
        echo "• Guides you through creating GitHub repositories"
        echo "• Provides step-by-step instructions to complete the setup"
        echo ""
        echo "Requirements:"
        echo "• Free GitHub account (we'll help you sign up if needed)"
        echo "• Administrator/sudo access (for installing system tools)"
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
