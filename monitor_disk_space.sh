#!/bin/bash
# ============================================================================
# DISK SPACE MONITORING AND ALERTING
# Runs as cron job to check disk usage and alert before issues occur
# ============================================================================

# Configuration
THRESHOLD=80  # Alert at 80% usage
CRITICAL=90   # Critical at 90% usage
LOG_FILE="/var/log/disk-monitor.log"
ALERT_EMAIL="admin@example.com"  # Change this

# Function to send alert
send_alert() {
    local message="$1"
    local level="$2"
    
    echo "$(date) - $level: $message" >> "$LOG_FILE"
    
    # Send to system log
    logger -t "disk-monitor" "$level: $message"
    
    # Send email (if mail command exists)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "Disk Space Alert - $level" "$ALERT_EMAIL"
    fi
    
    # Send to wall (all logged-in users)
    echo "DISK SPACE ALERT: $message" | wall
}

# Check disk usage
check_disk_usage() {
    local usage=$(df / --output=pcent | tail -1 | tr -d '% ')
    local available=$(df -h / --output=avail | tail -1)
    
    if [ "$usage" -ge "$CRITICAL" ]; then
        send_alert "CRITICAL: Root partition is ${usage}% full. Only ${available} available!" "CRITICAL"
        return 2
    elif [ "$usage" -ge "$THRESHOLD" ]; then
        send_alert "WARNING: Root partition is ${usage}% full. ${available} available." "WARNING"
        return 1
    else
        echo "$(date) - OK: Disk usage at ${usage}%" >> "$LOG_FILE"
        return 0
    fi
}

# Check Docker disk usage
check_docker_usage() {
    if command -v docker &> /dev/null; then
        local docker_usage=$(docker system df --format "{{.Size}}" 2>/dev/null | head -1 | sed 's/GB//' | sed 's/MB//')
        if [ -n "$docker_usage" ]; then
            # Rough check if Docker usage is high (>20GB)
            if echo "$docker_usage" | grep -q "GB" && [ "$(echo "$docker_usage" | sed 's/GB//')" -gt 20 ]; then
                send_alert "Docker is using ${docker_usage} of space" "WARNING"
            fi
        fi
    fi
}

# Check inode usage
check_inode_usage() {
    local inode_usage=$(df -i / --output=pcent | tail -1 | tr -d '% ')
    if [ "$inode_usage" -ge 85 ]; then
        send_alert "Inode usage at ${inode_usage}% (may run out of file handles)" "WARNING"
    fi
}

# Automated cleanup if critical
auto_cleanup() {
    local usage=$(df / --output=pcent | tail -1 | tr -d '% ')
    if [ "$usage" -ge "$CRITICAL" ]; then
        echo "Auto-cleanup triggered at $(date)" >> "$LOG_FILE"
        
        # Emergency cleanup
        find /var/lib/docker/containers -name "*.log" -type f -size +10M -exec truncate -s 0 {} \; 2>/dev/null
        journalctl --vacuum-time=1h 2>/dev/null
        docker system prune -f --filter "until=24h" 2>/dev/null
        apt clean 2>/dev/null
        
        # Check again
        local new_usage=$(df / --output=pcent | tail -1 | tr -d '% ')
        echo "After auto-cleanup: ${new_usage}%" >> "$LOG_FILE"
    fi
}

# Main
check_disk_usage
check_docker_usage
check_inode_usage
auto_cleanup