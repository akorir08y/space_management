#!/bin/bash
# ============================================================================
# DOCKER LOG ROTATION FIX SCRIPT
# Specifically targets Docker log issues that caused disk space exhaustion
# ============================================================================

set -euo pipefail

echo "=== FIXING DOCKER LOG ROTATION ==="

# Stop containers to prevent log writes during fix
echo "Stopping containers..."
docker stop $(docker ps -q) 2>/dev/null || true

# Clear all existing Docker logs
echo "Clearing existing Docker logs..."
find /var/lib/docker/containers -name "*.log" -type f -exec truncate -s 0 {} \;

# Remove rotated log files
echo "Removing old rotated logs..."
find /var/lib/docker/containers -name "*.log.*" -type f -delete 2>/dev/null || true

# Configure Docker daemon with log rotation
echo "Configuring Docker daemon..."
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "compress": "true",
    "labels": "production",
    "env": "production"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF

# Restart Docker
echo "Restarting Docker..."
systemctl restart docker

# Update docker-compose files to include logging
echo "Creating docker-compose template with log rotation..."
cat > /home/ubuntu/docker-compose-logging.yml << 'YAML'
version: '3.8'

services:
  # Template service with log rotation
  your-service:
    image: your-image:latest
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
        compress: "true"
    mem_limit: "1g"
    mem_reservation: "512m"
    restart: unless-stopped
YAML

# Create logrotate config for Docker logs
echo "Setting up logrotate for Docker..."
cat > /etc/logrotate.d/docker << 'EOF'
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        systemctl kill -s USR1 docker
    endscript
}
EOF

# Start containers again
echo "Starting containers..."
docker start $(docker ps -aq) 2>/dev/null || true

echo "=== DOCKER LOG FIX COMPLETE ==="
df -h /