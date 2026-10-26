#!/bin/bash

# ==============================================================================
# Script Name: server_check.sh
# Description: Analyzes core server performance stats, resource utilization,
#              system info, and recent security logs.
# ==============================================================================

clear
echo "========================================================"
echo "          SERVER PERFORMANCE & HEALTH REPORT            "
echo "========================================================"
printf "Generated on: %s\n\n" "$(date)"

# 1. System Information & Uptime
echo "--------------------------------------------------------"
echo " [System Information]"
echo "--------------------------------------------------------"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "OS Version:     $PRETTY_NAME"
else
    echo "OS Version:     $(uname -sr)"
fi
echo "Uptime:         $(uptime -p)"
echo "Load Average:   $(awk '{print "1-min:", $1, "| 5-min:", $2, "| 15-min:", $3}' /proc/loadavg)"
echo ""

# 2. User Activity
echo "--------------------------------------------------------"
echo " [Active Users]"
echo "--------------------------------------------------------"
LOGGED_USERS=$(who | wc -l)
if [ "$LOGGED_USERS" -gt 0 ]; then
    echo "Currently logged-in users ($LOGGED_USERS):"
    who | awk '{print "  - User:", $1, "(@ " $2 ") since", $3, $4}'
else
    echo "No active users logged in."
fi
echo ""

# 3. Failed Login Attempts
echo "--------------------------------------------------------"
echo " [Security: Failed Logins]"
echo "--------------------------------------------------------"
if command -v journalctl &> /dev/null; then
    FAILED_LOGINS=$(journalctl _COMM=sshd -g "Failed password" --since "24 hours ago" --no-pager 2>/dev/null | wc -l)
    echo "Failed SSH Login Attempts (Last 24h): $FAILED_LOGINS"
elif [ -f /var/log/auth.log ]; then
    FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    echo "Failed Login Attempts (auth.log): $FAILED_LOGINS"
else
    echo "Failed Login Attempts: Insufficient permissions or log not found."
fi
echo ""

# 4. CPU Usage
echo "--------------------------------------------------------"
echo " [CPU Usage]"
echo "--------------------------------------------------------"
CPU_IDLE=$(top -bn1 | grep -i "Cpu(s)" | awk '{print $8}' | cut -d'.' -f1)
if [ -z "$CPU_IDLE" ]; then
    CPU_IDLE=$(top -bn1 | grep -i "%Cpu" | awk '{print $8}' | cut -d'.' -f1)
fi
if [ -n "$CPU_IDLE" ]; then
    CPU_USAGE=$((100 - CPU_IDLE))
    echo "Total CPU Usage : ${CPU_USAGE}%"
    echo "CPU Idle        : ${CPU_IDLE}%"
else
    echo "Total CPU Usage : Unable to calculate"
fi
echo ""

# 5. Memory Usage
echo "--------------------------------------------------------"
echo " [Memory Usage]"
echo "--------------------------------------------------------"
free -h | awk '
NR==1 {print "Type   \tTotal\tUsed\tFree\tShared\tBuff/Cache\tAvailable"}
NR==2 {print "RAM:   \t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t\t"$7}
NR==3 {print "Swap:  \t"$2"\t"$3"\t"$4}'

# Calculate percentage
MEM_INFO=$(free | grep Mem:)
MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
MEM_PERCENT=$(( 100 * MEM_USED / MEM_TOTAL ))
echo ""
echo "Memory Utilization: ${MEM_PERCENT}% Used"
echo ""

# 6. Disk Usage (Root Partition)
echo "--------------------------------------------------------"
echo " [Disk Usage (/)]"
echo "--------------------------------------------------------"
df -h / | awk 'NR==1 {print} NR==2 {
    print "Filesystem :", $1
    print "Total Size :", $2
    print "Used       :", $3 " (" $5 ")"
    print "Free       :", $4
}'
echo ""

# 7. Top 5 Processes by CPU
echo "--------------------------------------------------------"
echo " [Top 5 Processes by CPU Usage]"
echo "--------------------------------------------------------"
printf "%-8s %-8s %-8s %s\n" "PID" "%CPU" "%MEM" "COMMAND"
ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -n 6 | tail -n 5 | awk '{printf "%-8s %-8s %-8s %s\n", $1, $2, $3, $4}'
echo ""

# 8. Top 5 Processes by Memory
echo "--------------------------------------------------------"
echo " [Top 5 Processes by Memory Usage]"
echo "--------------------------------------------------------"
printf "%-8s %-8s %-8s %s\n" "PID" "%CPU" "%MEM" "COMMAND"
ps -eo pid,%cpu,%mem,comm --sort=-%mem | head -n 6 | tail -n 5 | awk '{printf "%-8s %-8s %-8s %s\n", $1, $2, $3, $4}'
echo ""
echo "========================================================"
echo "                   REPORT COMPLETE                      "
echo "========================================================"
