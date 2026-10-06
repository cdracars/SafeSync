<div align="center">
  <img src="logo.png" alt="SafeSync Logo" width="200" height="200">
  
  # SafeSync
  
  **Universal Folder Backup System**
  
  *Point SafeSync at any folder → It stays backed up forever*
  
  Born for 3D printing configs, evolved for everything important.
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20WSL-blue.svg)](#platform-support)
  [![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](#)
</div>

## Support

If SafeSync is useful to you, you can support its continued upkeep on
[Ko-fi](https://ko-fi.com/cdracars66494).

---

## 🚀 What SafeSync Does

SafeSync is the **"set it and forget it"** backup solution for your important files.

- **🎯 Universal folder backup** - Works with ANY folder containing important files
- **🤖 Auto-detects 3D printing configs** - OrcaSlicer, PrusaSlicer, Klipper, and more
- **⚡ One-command setup** - `./easy-setup.sh --orcaslicer` and you're done
- **🔍 Real-time monitoring** - Watches folders for changes using system tools
- **📝 Automatic Git commits** - Every change gets timestamped and committed
- **☁️ Cloud backup** - Pushes to GitHub/GitLab for off-machine safety
- **⏰ Scheduled safety net** - Cron jobs ensure nothing is missed
- **🌐 Cross-platform** - Linux, Windows (WSL), macOS

**The philosophy:** Point it at a folder, and that folder stays backed up forever.

## 🎯 Perfect For

### 🖨️ 3D Printing (Our Specialty)
- **Slicer configurations** - OrcaSlicer, PrusaSlicer profiles and settings
- **Klipper setups** - printer.cfg, macros, mesh data (use KIAUH for Pi setup)
- **Printer firmware** - Marlin configs, OctoPrint settings
- **Spoolman/Docker** - docker-compose.yml and database backups

### 💻 Development & Gaming
- **Important config dirs** - `~/.config/someapp`, dotfiles, IDE settings
- **Small code projects** - Scripts, automation, personal tools
- **Game saves & configs** - Steam, emulator saves, game settings
- **Documentation** - Notes, wikis, important reference files

### ⚠️ Not Ideal For
- **Large binary files** - Big STL collections, video files (Git isn't great for this)
- **Active databases** - Unless you set up proper dump scripts
- **Highly volatile dirs** - Thousands of changes per day create noise

## 📋 Requirements

Before you start, make sure you have:

### ✅ **Required**
- **Free GitHub account** 
  - Sign up at: [github.com/join](https://github.com/join)
  - No paid features needed - free tier works perfectly
- **Administrator/sudo access** (for installing system tools if needed)

### 🔧 **Auto-Configured by SafeSync**
- **Git** - We'll install this for you if it's missing
- **SSH key setup** - We'll create and configure this for you
- **File monitoring tools** - We'll install these if you want them
  - Linux/WSL: `inotify-tools` 
  - macOS: `fswatch`
- **GitHub CLI** - We'll offer to install this for automatic repository creation
- **Git repository setup** - Initializes local repos and configures remotes

### 💡 **Optional Enhancements**
- **Cron jobs** for scheduled backups (we'll help set these up)
- **Real-time monitoring** for instant backups on file changes
- **Multiple folder setups** for organizing different config types
- **GitHub CLI** (`gh`) for automatic repository creation (optional but convenient)

Don't worry if you don't have everything - the setup wizard will guide you through getting what you need!

## 🏃‍♂️ Quick Start

### 🎯 Super Easy Mode (Recommended)
```bash
# Clone SafeSync
git clone https://github.com/cdracars/SafeSync.git
cd SafeSync

# Run the simple setup wizard
./easy-setup.sh

# That's it! The wizard will:
# • Check and install Git and monitoring tools for you
# • Offer to install GitHub CLI for automatic repository creation
# • Create SSH keys and set up GitHub connection securely
# • Find your 3D printing configs automatically
# • Help you set up any folder for backup  
# • Create GitHub repositories automatically (if you want)
# • Get everything working in minutes with minimal effort
```

### 🛠️ Manual Setup (Power Users)
```bash
# Setup ANY folder for backup
./setup-backup.sh "/path/to/your/folder" "your-repo-name"

# Start monitoring changes (optional - for real-time backup)
./monitor.sh "/path/to/your/folder" &

# Add scheduled backups (every 4 hours)
./install-cron.sh "/path/to/your/folder"
```

## 🛠️ What's Included

### Core Scripts
| Script | Purpose | Usage |
|--------|---------|-------|
| `easy-setup.sh` | **🌟 NEW!** Auto-detect & setup 3D printing configs | `./easy-setup.sh --orcaslicer` |
| `setup-backup.sh` | Initialize Git repo and set up remote | `./setup-backup.sh <folder> <repo-name>` |
| `backup.sh` | Manual backup execution | `./backup.sh <folder> [--verbose]` |
| `monitor.sh` | Real-time file monitoring | `./monitor.sh <folder> &` |
| `install-cron.sh` | Scheduled backup setup | `./install-cron.sh <folder> [hours]` |

### ✨ Easy Setup Features
- **🧙 Simple wizard** - Just run `./easy-setup.sh` and follow the prompts
- **🔍 Auto-detection** - Finds OrcaSlicer, PrusaSlicer, Klipper configs automatically
- **🛠️ Dependency management** - Installs Git and monitoring tools for you
- **🔐 SSH key creation** - Generates and helps you add keys to GitHub
- **📦 Repository automation** - Installs GitHub CLI and creates repositories automatically
- **🌐 Cross-platform** - Works on Windows (WSL), Linux, macOS
- **👶 Beginner-friendly** - No complex commands or configuration needed
- **🔧 Smart defaults** - Handles Git setup, branch naming, and repository creation

### Platform Support
- ✅ **Linux** - Full support with `inotifywait`
- ✅ **Windows (WSL)** - Full support + Windows integration
- ✅ **macOS** - Full support with `fswatch`

## 🎯 Current Limitations

**This is intentionally a simple system.** Here's what it doesn't do:

- ❌ No fancy UI or configuration management
- ❌ No automatic path detection (you specify the paths)
- ❌ No built-in restore functionality (just use `git checkout`)
- ❌ No compression or large file handling (use .gitignore for big files)
- ❌ No encryption or advanced security
- ❌ No conflict resolution for simultaneous changes

**But it's reliable** for the core use case: automated Git commits of important configs.

## 📋 Setup Examples

### 🎯 Super Easy Mode
```bash
# Just run the wizard - it does everything for you!
./easy-setup.sh

# The wizard will:
# 1. Find your configs automatically
# 2. Ask simple yes/no questions  
# 3. Set up Git and remote repositories
# 4. Get everything working in minutes
```

### 🖨️ 3D Printing Configs (Manual)
```bash
# OrcaSlicer configurations
# Windows (WSL):
./setup-backup.sh "/mnt/c/Users/$USER/AppData/Roaming/OrcaSlicer/user/default" "orcaslicer-configs"

# Linux:
./setup-backup.sh ~/.config/OrcaSlicer "orcaslicer-configs"

# macOS:
./setup-backup.sh "~/Library/Application Support/OrcaSlicer" "orcaslicer-configs"

# Klipper configurations (use KIAUH for Pi setup: https://github.com/th33xitus/kiauh)
./setup-backup.sh ~/klipper_config "klipper-setup"
./setup-backup.sh ~/printer_data/config "klipper-configs"
```

### 💻 Development & Other Configs
```bash
# Important config directories
./setup-backup.sh ~/.config/VSCode "vscode-settings"
./setup-backup.sh ~/.config/fish "fish-config"
./setup-backup.sh ~/.dotfiles "dotfiles-backup"

# Game saves and configs
./setup-backup.sh ~/.steam/steam/userdata "steam-saves"
./setup-backup.sh ~/.config/lutris "lutris-configs"

# Documentation and notes
./setup-backup.sh ~/Documents/important-docs "important-docs"
./setup-backup.sh ~/obsidian-vault "obsidian-notes"
```

### 📁 Any Folder Backup
```bash
# Literally any folder
./setup-backup.sh "/path/to/any/folder" "my-backup-repo"
```

## ⚙️ How The Scripts Work

<details>
<summary>🔧 setup-backup.sh</summary>

- Detects your platform (Linux/WSL/macOS)
- Checks for Git and file monitoring tools
- Initializes Git repo in your target folder
- Creates smart .gitignore based on detected file types
- Sets up GitHub/GitLab remote repository
- Tests the setup with an initial commit
</details>

<details>
<summary>💾 backup.sh</summary>

- Checks if Git repo has changes (`git status --porcelain`)
- Commits changes with timestamp: "Automatic backup YYYY-MM-DD HH:MM:SS"
- Pushes to remote repository
- Handles push failures gracefully (commits locally)
- Supports verbose output and dry-run mode
</details>

<details>
<summary>👁️ monitor.sh</summary>

- Uses `inotifywait` (Linux/WSL) or `fswatch` (macOS) to watch files
- Waits 10 seconds after detecting changes (configurable)
- Calls `backup.sh` to create commit and push
- Runs continuously until stopped (Ctrl+C)
- Excludes common temporary files (.tmp, .log, etc.)
</details>

<details>
<summary>⏰ install-cron.sh</summary>

- Sets up cron jobs for scheduled backups
- Default: every 4 hours, customizable
- Creates log files in `~/.safesync/logs/`
- Can list existing jobs or remove backup jobs
- Validates backup system before installing cron job
</details>

## 📦 Installation Requirements

### Linux/WSL
```bash
sudo apt install git inotify-tools    # Ubuntu/Debian
sudo yum install git inotify-tools    # RHEL/CentOS
```

### macOS
```bash
brew install git fswatch
```

### Windows
Use WSL (Windows Subsystem for Linux) and follow Linux instructions.

## 🔐 Setting Up Git Authentication

### SSH (Recommended)
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Add public key to GitHub/GitLab
cat ~/.ssh/id_ed25519.pub
# Copy this and add to your Git provider's SSH Keys

# Test connection
ssh -T git@github.com
```

### HTTPS (Alternative)
The setup script will prompt for GitHub username and offer both SSH and HTTPS options.

## 🎮 Manual Commands

```bash
# Easy setup wizard (recommended)
./easy-setup.sh                    # Simple guided setup

# Manual backup operations
./backup.sh /path/to/folder         # One-time backup
./backup.sh /path/to/folder --verbose  # Verbose output

# File monitoring
./monitor.sh /path/to/folder &      # Start real-time monitoring

# Scheduled backups
./install-cron.sh /path/to/folder   # Every 4 hours (default)
./install-cron.sh /path/to/folder 2 # Every 2 hours
./install-cron.sh --list           # View current backup jobs
./install-cron.sh --remove         # Remove all backup jobs
```

## 🐛 Troubleshooting

<details>
<summary>🏗️ "Repository needs to be created manually"</summary>

SafeSync can create repositories automatically if you have GitHub CLI:

```bash
# If you missed it during setup, install GitHub CLI:
# Ubuntu/Debian:
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update && sudo apt install gh

# macOS:
brew install gh

# Then authenticate and create repository:
gh auth login
gh repo create your-repo-name --public

# Manual option - Use GitHub web interface:
# Go to: https://github.com/new
# Create repository with the name shown in the setup output
```
</details>

<details>
<summary>🚫 "Git push failed"</summary>

```bash
# Check if remote repository exists
git remote -v

# Test SSH connection
ssh -T git@github.com

# Try manual push
cd /your/folder && git push origin master
```
</details>

<details>
<summary>🔍 "inotifywait: command not found" (Linux)</summary>

```bash
sudo apt install inotify-tools
```
</details>

<details>
<summary>🍎 "fswatch: command not found" (macOS)</summary>

```bash
brew install fswatch
```
</details>

<details>
<summary>📝 "No changes detected" but files changed</summary>

```bash
# Check git status manually
cd /your/folder && git status

# Check .gitignore isn't excluding everything
cat .gitignore
```
</details>

<details>
<summary>👀 Monitor script stops working</summary>

```bash
# Check if it's still running
ps aux | grep monitor.sh

# Restart monitoring
./monitor.sh /path/to/folder &
```
</details>

### 📄 Log Locations
- **Cron logs**: `~/.safesync/logs/backup-*.log`
- **System cron**: `grep CRON /var/log/syslog` (Linux)
- **Monitor logs**: Check terminal output where monitor.sh was started

## ✅ Real-World Testing

### What We Actually Tested
- ✅ OrcaSlicer configs on Windows WSL
- ✅ Klipper configs on Raspberry Pi
- ✅ Spoolman Docker setup with database dumps
- ✅ Multiple printers with separate repos
- ✅ Cross-platform file monitoring
- ✅ Cron job scheduling and reliability

### Performance Notes
- **Small config files** (< 1MB): Works perfectly
- **Medium collections** (1-50MB): Works well with .gitignore
- **Large binary files**: Use .gitignore to exclude or consider Git LFS
- **Database files**: Set up proper dump scripts

## 🤝 Contributing

This is intentionally a simple system. If you want to add features:

1. Keep scripts simple and readable
2. Maintain cross-platform compatibility
3. Don't add dependencies unless absolutely necessary
4. Test on multiple platforms
5. Update examples with real-world use cases

## 📄 License

MIT License - use it however you want.

## 💭 Why SafeSync Exists

**Because your carefully tuned configs are irreplaceable.**

Started as a solution for 3D printing enthusiasts who spent hours perfecting their slicer settings, only to lose them to corrupted profiles or system crashes. 

**The core insight:** Most "important" files are small configs that change occasionally - perfect for Git.

**The evolution:** What works for printer profiles works for game saves, development configs, documentation, and any folder containing files you can't afford to lose.

**The philosophy:** Point SafeSync at a folder → It stays backed up forever.

No complex setup, no learning curve, no maintenance. Just reliable, automatic backups of the files that matter to you.

---

<div align="center">
  <strong>Current Status:</strong> Battle-tested and actively used.<br>
  Trusted by 3D printing enthusiasts and developers worldwide.<br>
  Works reliably for any important folder.
  
  <br><br>
  
  ⭐ **Star this repo if SafeSync saved your configs!** ⭐
</div>
