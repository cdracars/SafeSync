<div align="center">
  <img src="logo.png" alt="SafeSync Logo" width="200" height="200">
  
  # SafeSync
  
  **Simple Automated Backup System**
  
  *A lightweight, Git-based backup solution that automatically commits and pushes changes from any folder.*
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20WSL-blue.svg)](#platform-support)
  [![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](#)
</div>

---

## 🚀 What SafeSync Actually Does

- **🔍 Watches folders** for file changes using `inotifywait` (Linux/WSL) or `fswatch` (macOS)
- **📝 Automatically commits** changes to local Git repositories with timestamps
- **☁️ Pushes to remote** repositories (GitHub, GitLab, etc.) for off-machine backup
- **⏰ Scheduled backups** via cron jobs every few hours as a safety net
- **🌐 Cross-platform** - works on Linux, Windows (WSL), and macOS
- **⚡ Simple setup** - just point it at folders you want backed up

## 📁 Real Use Cases

### 🖨️ 3D Printing
- **OrcaSlicer/PrusaSlicer configs** - printer profiles, print settings, filament settings
- **Klipper configurations** - printer.cfg, macros, mesh data
- **Spoolman Docker setups** - docker-compose.yml and database backups
- **Firmware configurations** - Marlin configs, OctoPrint settings

### 💻 Development & Config
- **Important config directories** (`~/.config/someapp`)
- **Small code projects** and scripts
- **Documentation folders** and notes
- **Dotfiles and system configurations**

### ⚠️ What Doesn't Work Well
- **Large binary files** (CAD files, big STL collections) - Git isn't ideal for this
- **Frequently changing databases** - unless you set up proper database dumps
- **Very active directories** - too many commits can be noisy

## 🏃‍♂️ Quick Start

```bash
# Clone this repo
git clone https://github.com/yourusername/SafeSync.git
cd SafeSync

# Make scripts executable
chmod +x *.sh

# Setup a folder for backup
./setup-backup.sh "/path/to/your/folder" "your-repo-name"

# Start monitoring (optional - for immediate backups on file changes)
./monitor.sh "/path/to/your/folder" &

# Add scheduled backups (every 4 hours)
./install-cron.sh "/path/to/your/folder"
```

## 🛠️ What's Included

### Core Scripts
| Script | Purpose | Usage |
|--------|---------|-------|
| `setup-backup.sh` | Initialize Git repo and set up remote | `./setup-backup.sh <folder> <repo-name>` |
| `backup.sh` | Manual backup execution | `./backup.sh <folder> [--verbose]` |
| `monitor.sh` | Real-time file monitoring | `./monitor.sh <folder> &` |
| `install-cron.sh` | Scheduled backup setup | `./install-cron.sh <folder> [hours]` |

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

### 🖨️ OrcaSlicer Backup
```bash
# Windows (WSL):
./setup-backup.sh "/mnt/c/Users/$USER/AppData/Roaming/OrcaSlicer/user/default" "orcaslicer-configs"

# Linux:
./setup-backup.sh ~/.config/OrcaSlicer "orcaslicer-configs"

# macOS:
./setup-backup.sh "~/Library/Application Support/OrcaSlicer" "orcaslicer-configs"
```

### 🖥️ Klipper Config Backup
```bash
./setup-backup.sh ~/klipper_config "klipper-setup"
./setup-backup.sh ~/printer_data/config "klipper-configs"
```

### 📁 Any Folder Backup
```bash
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
# Manual backup
./backup.sh /path/to/folder

# Start file monitoring
./monitor.sh /path/to/folder &

# Set up scheduled backups (every 4 hours)
./install-cron.sh /path/to/folder

# Set up scheduled backups (every 2 hours)
./install-cron.sh /path/to/folder 2

# View current backup cron jobs
./install-cron.sh --list

# Remove all backup cron jobs
./install-cron.sh --remove
```

## 🐛 Troubleshooting

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

## 💭 Why This Exists

Because sometimes you just want your important configs automatically backed up without learning a complex system. This does exactly that - nothing more, nothing less.

**The core concept is simple: Git + automation = reliable backups**

---

<div align="center">
  <strong>Current Status:</strong> Functional and tested on multiple platforms.<br>
  Used daily for 3D printing configs and other small file collections.<br>
  Works reliably for the intended use case.
  
  <br><br>
  
  ⭐ **Star this repo if SafeSync helped you!** ⭐
</div>