#!/bin/bash
# ============================================================================
# MASTER LINUX CLEANUP SCRIPT
# Combines all space-saving techniques from the troubleshooting session
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
LOG_FILE="/var/log/system-cleanup-$(date +%Y%m%d).log"
DRY_RUN=false
VERBOSE=false

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --help) 
            echo "Usage: $0 [--dry-run] [--verbose]"
            exit 0
            ;;
        *) shift ;;
    esac
done

# Start cleanup
log_message "Starting system cleanup (Dry run: $DRY_RUN)"
print_header "System Cleanup Started"
df -h / | tee -a "$LOG_FILE"

# ============================================================================
# 1. DOCKER SPACE MANAGEMENT
# ============================================================================
cleanup_docker() {
    print_header "1. Cleaning Docker"
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not installed"
        return
    fi
    
    # Check Docker disk usage
    log_message "Docker disk usage before:"
    docker system df >> "$LOG_FILE" 2>&1
    
    if [ "$DRY_RUN" = false ]; then
        # Clean containers, images, volumes
        docker container prune -f >> "$LOG_FILE" 2>&1 && print_success "Removed stopped containers"
        docker image prune -a -f >> "$LOG_FILE" 2>&1 && print_success "Removed unused images"
        docker volume prune -f >> "$LOG_FILE" 2>&1 && print_success "Removed unused volumes"
        docker network prune -f >> "$LOG_FILE" 2>&1 && print_success "Removed unused networks"
        docker builder prune -f >> "$LOG_FILE" 2>&1 && print_success "Removed build cache"
        docker system prune -a -f --volumes >> "$LOG_FILE" 2>&1 && print_success "System-wide Docker cleanup"
        
        # Clear Docker logs
        find /var/lib/docker/containers -name "*.log" -type f -size +10M -exec truncate -s 0 {} \; \
            2>/dev/null && print_success "Truncated large Docker logs"
    else
        print_warning "Would clean Docker system (dry run)"
    fi
    
    log_message "Docker disk usage after:"
    docker system df >> "$LOG_FILE" 2>&1
}

# ============================================================================
# 2. SYSTEM LOG MANAGEMENT
# ============================================================================
cleanup_logs() {
    print_header "2. Cleaning System Logs"
    
    if [ "$DRY_RUN" = false ]; then
        # Journald logs
        journalctl --vacuum-time=7d >> "$LOG_FILE" 2>&1 && print_success "Cleaned journald logs (kept 7 days)"
        journalctl --vacuum-size=500M >> "$LOG_FILE" 2>&1 && print_success "Limited journald to 500MB"
        
        # Old log files
        find /var/log -name "*.gz" -type f -mtime +30 -delete 2>/dev/null && \
            print_success "Removed old compressed logs"
        find /var/log -name "*.1" -type f -mtime +30 -delete 2>/dev/null && \
            print_success "Removed old rotated logs"
        find /var/log -name "*.log.*" -type f -mtime +30 -delete 2>/dev/null && \
            print_success "Removed old log backups"
        
        # Rotate logs
        logrotate -f /etc/logrotate.conf >> "$LOG_FILE" 2>&1 && print_success "Forced log rotation"
        
        # Cloud-init logs (AWS)
        rm -f /var/log/cloud-init*.log 2>/dev/null && print_success "Removed cloud-init logs"
    else
        print_warning "Would clean system logs (dry run)"
    fi
}

# ============================================================================
# 3. PACKAGE MANAGEMENT
# ============================================================================
cleanup_packages() {
    print_header "3. Cleaning Package Manager"
    
    if [ "$DRY_RUN" = false ]; then
        # APT cleanup
        apt-get autoremove -y >> "$LOG_FILE" 2>&1 && print_success "Removed unused packages"
        apt-get autoclean -y >> "$LOG_FILE" 2>&1 && print_success "Cleaned package cache"
        apt-get clean -y >> "$LOG_FILE" 2>&1 && print_success "Removed downloaded packages"
        rm -rf /var/lib/apt/lists/* >> "$LOG_FILE" 2>&1 && print_success "Removed package lists"
        
        # Remove old kernels (keep current + 1)
        current_kernel=$(uname -r | sed 's/-aws//g' | sed 's/-generic//g')
        kernels_to_remove=$(dpkg -l | grep 'linux-image' | grep -v "$current_kernel" | \
            grep -v "linux-image-aws" | awk '{print $2}' | tail -n +3)
        
        for kernel in $kernels_to_remove; do
            apt-get remove --purge -y "$kernel" >> "$LOG_FILE" 2>&1 && \
                print_success "Removed old kernel: $kernel"
        done
    else
        print_warning "Would clean packages (dry run)"
    fi
    
    # Update package lists
    apt-get update >> "$LOG_FILE" 2>&1 && print_success "Updated package lists"
}

# ============================================================================
# 4. TEMPORARY FILES
# ============================================================================
cleanup_temp() {
    print_header "4. Cleaning Temporary Files"
    
    if [ "$DRY_RUN" = false ]; then
        rm -rf /tmp/* >> "$LOG_FILE" 2>&1 && print_success "Cleaned /tmp"
        rm -rf /var/tmp/* >> "$LOG_FILE" 2>&1 && print_success "Cleaned /var/tmp"
        
        # User caches
        find /home -type d -name ".cache" -exec rm -rf {} \; 2>/dev/null && \
            print_success "Cleaned user caches"
        find /home -type d -name "thumbnails" -exec rm -rf {} \; 2>/dev/null && \
            print_success "Cleaned thumbnails"
        
        # Trash bins
        find /home -type d -path "*/.local/share/Trash/*" -delete 2>/dev/null && \
            print_success "Emptied trash bins"
    else
        print_warning "Would clean temp files (dry run)"
    fi
}

# ============================================================================
# 5. NODE.JS/NPM SPACE
# ============================================================================
cleanup_node() {
    print_header "5. Cleaning Node.js/NPM"
    
    if command -v npm &> /dev/null; then
        if [ "$DRY_RUN" = false ]; then
            npm cache clean --force >> "$LOG_FILE" 2>&1 && print_success "Cleaned npm cache"
            rm -rf ~/.npm/_logs 2>/dev/null && print_success "Removed npm logs"
            rm -rf ~/.npm/_cacache 2>/dev/null && print_success "Removed npm cache"
        else
            print_warning "Would clean npm cache (dry run)"
        fi
    fi
    
    if command -v yarn &> /dev/null; then
        if [ "$DRY_RUN" = false ]; then
            yarn cache clean >> "$LOG_FILE" 2>&1 && print_success "Cleaned yarn cache"
        else
            print_warning "Would clean yarn cache (dry run)"
        fi
    fi
    
    # Remove temp node_modules
    find /tmp /var/tmp -name "node_modules" -type d -exec rm -rf {} \; 2>/dev/null && \
        print_success "Removed temporary node_modules"
}

# ============================================================================
# 6. SNAP PACKAGES
# ============================================================================
cleanup_snap() {
    print_header "6. Cleaning Snap Packages"
    
    if command -v snap &> /dev/null; then
        if [ "$DRY_RUN" = false ]; then
            # Remove disabled revisions
            snap list --all | grep disabled | awk '{print $1, $2}' | while read snapname revision; do
                snap remove "$snapname" --revision="$revision" >> "$LOG_FILE" 2>&1 && \
                    print_success "Removed old snap: $snapname (rev $revision)"
            done
            
            # Clean cache
            rm -rf /var/lib/snapd/cache/* >> "$LOG_FILE" 2>&1 && print_success "Cleaned snap cache"
        else
            print_warning "Would clean snap packages (dry run)"
        fi
    fi
}

# ============================================================================
# 7. CORE DUMPS AND CRASH REPORTS
# ============================================================================
cleanup_coredumps() {
    print_header "7. Cleaning Core Dumps"
    
    if [ "$DRY_RUN" = false ]; then
        rm -f /var/lib/systemd/coredump/* 2>/dev/null && print_success "Removed core dumps"
        rm -f /var/crash/* 2>/dev/null && print_success "Removed crash reports"
    else
        print_warning "Would remove core dumps (dry run)"
    fi
}

# ============================================================================
# 8. CREATE SWAP SPACE
# ============================================================================
setup_swap() {
    print_header "8. Setting Up Swap Space"
    
    if [ "$DRY_RUN" = false ]; then
        if [ ! -f /swapfile ]; then
            fallocate -l 2G /swapfile >> "$LOG_FILE" 2>&1
            chmod 600 /swapfile
            mkswap /swapfile >> "$LOG_FILE" 2>&1
            swapon /swapfile >> "$LOG_FILE" 2>&1
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
            print_success "Created 2GB swap file"
        else
            print_success "Swap file already exists"
        fi
    else
        print_warning "Would create swap file (dry run)"
    fi
}

# ============================================================================
# 9. CONFIGURE DOCKER LOG ROTATION
# ============================================================================
configure_docker_logging() {
    print_header "9. Configuring Docker Log Rotation"
    
    if [ "$DRY_RUN" = false ]; then
        cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "compress": "true"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF
        systemctl restart docker >> "$LOG_FILE" 2>&1
        print_success "Configured Docker log rotation and restarted Docker"
    else
        print_warning "Would configure Docker logging (dry run)"
    fi
}

# ============================================================================
# 10. DISPLAY FINAL REPORT
# ============================================================================
show_report() {
    print_header "Cleanup Complete - Final Report"
    
    echo -e "\n${GREEN}Disk Usage After Cleanup:${NC}"
    df -h /
    
    echo -e "\n${GREEN}Top 10 Largest Directories:${NC}"
    du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
    
    echo -e "\n${GREEN}Docker Disk Usage:${NC}"
    docker system df 2>/dev/null || echo "Docker not available"
    
    echo -e "\n${GREEN}Memory Status:${NC}"
    free -h
    
    echo -e "\n${GREEN}Swap Status:${NC}"
    swapon --show || echo "No swap configured"
    
    echo -e "\n${GREEN}Log File: ${LOG_FILE}${NC}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
main() {
    print_header "Starting Comprehensive System Cleanup"
    log_message "Cleanup initiated by user"
    
    # Execute all cleanup functions
    cleanup_docker
    cleanup_logs
    cleanup_packages
    cleanup_temp
    cleanup_node
    cleanup_snap
    cleanup_coredumps
    setup_swap
    configure_docker_logging
    
    # Show final report
    show_report
    
    log_message "Cleanup completed successfully"
    print_success "\nCleanup Finished!"
}

# Run main function
main