# 🧹 Linux System Cleanup & Docker Log Management Scripts

A comprehensive collection of shell scripts for automated Linux system maintenance, Docker log management, disk space monitoring, and emergency recovery.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)

## 📋 Table of Contents
- [Features](#features)
- [Scripts Overview](#scripts-overview)
- [Quick Installation](#quick-installation)
- [Usage Guide](#usage-guide)
- [Automation Setup](#automation-setup)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

- **Docker Space Management** - Automatic log rotation, container pruning, image cleanup
- **System Log Rotation** - Journald limits, logrotate configuration, old log removal
- **Package Management** - APT cache cleanup, old kernel removal, orphaned packages
- **Node.js/NPM Cleanup** - Cache cleaning, node_modules removal, yarn cache management
- **Emergency Recovery** - Critical space recovery when disk is full
- **Automated Monitoring** - Disk usage alerts, automated cleanup triggers
- **AWS Optimized** - Cloud-init logs, SSM agent logs, EBS optimizations

## 📜 Scripts Overview

| Script | Purpose | Use Case |
|--------|---------|----------|
| `cleanup-system.sh` | Comprehensive system cleanup | Daily/weekly maintenance |
| `fix-docker-logs.sh` | Docker log rotation fix | When Docker logs fill disk |
| `monitor-disk-space.sh` | Disk usage monitoring | Cron-based monitoring |
| `emergency-recovery.sh` | Critical space recovery | When disk is 90%+ full |

## 🚀 Quick Installation

### One-Line Installation

```bash
# Clone repository
git clone https://github.com/YOUR-USERNAME/linux-cleanup-scripts.git
cd linux-cleanup-scripts

# Install scripts system-wide
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/*.sh

# Run initial cleanup
sudo /usr/local/bin/cleanup-system.sh


Manual Installation

# 1. Download individual scripts
sudo curl -o /usr/local/bin/cleanup-system.sh \
  https://raw.githubusercontent.com/YOUR-USERNAME/linux-cleanup-scripts/main/scripts/cleanup-system.sh

# 2. Make executable
sudo chmod +x /usr/local/bin/*.sh

# 3. Test dry run
sudo /usr/local/bin/cleanup-system.sh --dry-run

Usage Guide

# Full system cleanup (with confirmation)
sudo cleanup-system.sh

# Dry run (preview what will be cleaned)
sudo cleanup-system.sh --dry-run

# Verbose mode with detailed output
sudo cleanup-system.sh --verbose

# Fix Docker logs specifically
sudo fix-docker-logs.sh

# Emergency recovery when disk is full
sudo emergency-recovery.sh

# Monitor disk space manually
sudo monitor-disk-space.sh

Fixing Held Storage
When files are deleted but space isn't freed. Here is how to identify and fix this

# Find all deleted files still open by processes
sudo lsof +L1 | grep -i deleted

# More detailed view
sudo lsof +L1 | awk '{print $1, $2, $7, $8, $9, $10}' | column -t

# Count total space held
sudo lsof +L1 | grep -i deleted | awk '{sum+=$7} END {print "Total space held: " sum/1024/1024 " MB"}'

# Show deleted files sorted by size
sudo lsof +L1 | grep -i deleted | sort -k7 -rn | head -20

# Show only large files (>10MB)
sudo lsof +L1 | awk '$7 > 10000000 && /deleted/' | sort -k7 -rn

# Get process details for each deleted file
sudo lsof +L1 | grep -i deleted | while read line; do
    pid=$(echo $line | awk '{print $2}')
    size=$(echo $line | awk '{print $7}')
    file=$(echo $line | awk '{print $9}')
    echo "PID: $pid, Size: $(numfmt --to=iec $size), File: $file"
done


Make the executable file and run the check held storage script

chmod +x check_held_storage.sh
sudo ./check_held_storage.sh

Watch for held storage

# Watch command to monitor held files
watch -n 2 'sudo lsof +L1 | grep -i deleted | awk "{sum+=\$7} END {printf \"Total held: %.2f MB\n\", sum/1024/1024}"'

# Monitor with process details
watch -n 2 'sudo lsof +L1 | grep -i deleted | head -20'