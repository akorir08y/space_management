#!/bin/bash
# ============================================================================
# CHECK STORAGE HELD BY RUNNING PROCESSES
# Identifies files that are deleted but still held open by processes
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== STORAGE HELD BY RUNNING PROCESSES ===${NC}"
echo ""

# 1. Check for deleted files
echo -e "${YELLOW}1. Deleted Files Still Open:${NC}"
deleted_files=$(sudo lsof +L1 2>/dev/null | grep -i deleted | wc -l)
if [ "$deleted_files" -gt 0 ]; then
    echo -e "${RED}Found $deleted_files deleted files still held open${NC}"
    sudo lsof +L1 2>/dev/null | grep -i deleted | awk '{
        printf "  PID: %-8s Process: %-15s Size: %-10s File: %s\n", $2, $1, $7, $9
    }'
    
    # Calculate total space
    total_space=$(sudo lsof +L1 2>/dev/null | grep -i deleted | awk '{sum+=$7} END {print sum}')
    echo -e "${RED}  Total space held: $(numfmt --to=iec $total_space 2>/dev/null || echo "$total_space bytes")${NC}"
else
    echo -e "${GREEN}No deleted files held by processes${NC}"
fi

echo ""

# 2. Check large log files being written
echo -e "${YELLOW}2. Large Open Log Files (Active writes):${NC}"
sudo lsof 2>/dev/null | grep -E "\.log$" | awk '{print $1, $2, $7, $9}' | sort -k3 -rn | head -10 | while read proc pid size file; do
    if [ "$size" -gt 10485760 ]; then  # >10MB
        echo -e "${RED}  $proc (PID: $pid) - $(numfmt --to=iec $size 2>/dev/null): $file${NC}"
    else
        echo "  $proc (PID: $pid) - $(numfmt --to=iec $size 2>/dev/null): $file"
    fi
done

echo ""

# 3. Check specific common culprits
echo -e "${YELLOW}3. Checking Common Culprits:${NC}"

# Docker logs
docker_logs=$(sudo lsof +L1 2>/dev/null | grep -c "docker.*json.log")
if [ "$docker_logs" -gt 0 ]; then
    echo -e "  ${RED}Docker logs: $docker_logs files held open${NC}"
fi

# Journald
journal=$(sudo lsof +L1 2>/dev/null | grep -c "journal")
if [ "$journal" -gt 0 ]; then
    echo -e "  ${RED}Systemd journal: $journal files held open${NC}"
fi

# MySQL/MariaDB
mysql=$(sudo lsof +L1 2>/dev/null | grep -c "mysql\|ibdata")
if [ "$mysql" -gt 0 ]; then
    echo -e "  ${YELLOW}MySQL files: $mysql files held open${NC}"
fi

# PostgreSQL
pgsql=$(sudo lsof +L1 2>/dev/null | grep -c "postgres")
if [ "$pgsql" -gt 0 ]; then
    echo -e "  ${YELLOW}PostgreSQL: $pgsql files held open${NC}"
fi

echo ""

# 4. Show processes with many open file handles
echo -e "${YELLOW}4. Processes with Most Open File Handles:${NC}"
sudo lsof 2>/dev/null | awk '{print $1, $2}' | sort | uniq -c | sort -rn | head -10 | while read count proc pid; do
    echo "  $proc (PID: $pid) - $count files"
done

echo ""

# 5. Check file descriptor limits
echo -e "${YELLOW}5. Process File Descriptor Limits:${NC}"
for pid in $(sudo lsof +L1 2>/dev/null | grep -i deleted | awk '{print $2}' | sort -u | head -5); do
    if [ -n "$pid" ]; then
        proc_name=$(ps -p $pid -o comm= 2>/dev/null)
        limit=$(cat /proc/$pid/limits 2>/dev/null | grep "open files" | awk '{print $4}')
        current=$(sudo lsof -p $pid 2>/dev/null | wc -l)
        echo "  $proc_name (PID: $pid) - Current: $current, Limit: $limit"
    fi
done

echo ""

# 6. Disk space impact
echo -e "${YELLOW}6. Disk Space Impact:${NC}"
if [ "$deleted_files" -gt 0 ]; then
    echo -e "  ${RED}WARNING: Space is being held by running processes${NC}"
    echo "  To free space: Restart the processes holding the files"
else
    echo -e "  ${GREEN}No processes holding deleted files${NC}"
fi

echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. To free space without restarting:"
echo "   sudo kill -HUP <PID>  # Reload process"
echo "   sudo truncate -s 0 /proc/<PID>/fd/<FD>  # Clear file descriptor"
echo "2. To forcefully free space (restart process):"
echo "   sudo systemctl restart <service>"
echo "3. To monitor real-time:"
echo "   watch -n 1 'sudo lsof +L1 | grep -i deleted | wc -l'"