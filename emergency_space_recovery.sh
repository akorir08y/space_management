#!/bin/bash
# ============================================================================
# EMERGENCY RECOVERY SCRIPT
# For when disk space is critically low and system is failing
# ============================================================================

echo "=== EMERGENCY DISK SPACE RECOVERY ==="
echo "This script will attempt to recover critical disk space"

# Stop services that might be writing logs
echo "Stopping services..."
systemctl stop docker 2>/dev/null
systemctl stop rsyslog 2>/dev/null

# Emergency log cleanup
echo "Clearing Docker logs..."
find /var/lib/docker/containers -name "*.log" -type f -exec truncate -s 0 {} \; 2>/dev/null

echo "Clearing system logs..."
journalctl --vacuum-size=50M 2>/dev/null
rm -rf /var/log/*.gz 2>/dev/null
rm -rf /var/log/*.1 2>/dev/null

echo "Clearing package cache..."
apt-get clean 2>/dev/null
rm -rf /var/lib/apt/lists/* 2>/dev/null

echo "Clearing temporary files..."
rm -rf /tmp/* /var/tmp/* 2>/dev/null

echo "Removing core dumps..."
rm -rf /var/lib/systemd/coredump/* 2>/dev/null
rm -rf /var/crash/* 2>/dev/null

# Remove old kernels (keep only current)
echo "Removing old kernels..."
current_kernel=$(uname -r | sed 's/-aws//g')
dpkg -l | grep 'linux-image' | grep -v "$current_kernel" | awk '{print $2}' | xargs -r apt-get remove --purge -y 2>/dev/null

# Create swap if missing
if [ ! -f /swapfile ] && [ "$(df / --output=avail | tail -1)" -gt 2000000 ]; then
    echo "Creating swap file..."
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
fi

# Restart services
echo "Restarting services..."
systemctl start docker 2>/dev/null
systemctl start rsyslog 2>/dev/null

# Display results
echo -e "\n=== RECOVERY COMPLETE ==="
df -h /
echo -e "\nSpace recovered! You should now have at least 10-15% free space."