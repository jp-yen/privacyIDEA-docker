#!/bin/bash

# Automated Database Backup Script for Cron
# This script performs automatic backups with rotation
# Suitable for cron execution

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"
DATE=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/backup_cron_$(date +"%Y%m").log"

# Backup retention settings
KEEP_DAILY=7      # Keep daily backups for 7 days
KEEP_WEEKLY=4     # Keep weekly backups for 4 weeks
KEEP_MONTHLY=12   # Keep monthly backups for 12 months

# Create directories if they don't exist
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check disk space (require at least 1GB free)
check_disk_space() {
    local required_space=1048576  # 1GB in KB
    local available_space=$(df "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        log "ERROR: Insufficient disk space. Required: 1GB, Available: $(($available_space/1024))MB"
        exit 1
    fi
    
    log "Disk space check passed. Available: $(($available_space/1024/1024))GB"
}

# Function to check if services are running
check_services() {
    if ! docker ps --format "{{.Names}}" | grep -q "^PostgreSQL$"; then
        log "ERROR: PostgreSQL container is not running"
        exit 1
    fi
    log "Service check passed"
}

# Function to load environment variables
load_env() {
    if [ -f "$PROJECT_DIR/.env" ]; then
        source "$PROJECT_DIR/.env"
        log "Environment variables loaded"
    else
        log "ERROR: .env file not found"
        exit 1
    fi
    
    if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
        log "ERROR: Database credentials not found in .env"
        exit 1
    fi
}

# Function to create backup
create_backup() {
    local backup_type="$1"
    local filename="$BACKUP_DIR/privacyidea_${backup_type}_${DATE}.sql"
    
    log "Starting $backup_type backup: $(basename "$filename")"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    # Create backup with error handling
    if docker exec PostgreSQL pg_dump \
        -U "$DB_USER" \
        -d privacyidea \
        --verbose \
        --no-password > "$filename" 2>>"$LOG_FILE"; then
        
        local file_size=$(du -h "$filename" | cut -f1)
        log "Backup completed successfully: $(basename "$filename") ($file_size)"
        
        # Compress backup if larger than 10MB
        if [ $(stat -c%s "$filename" 2>/dev/null || echo "0") -gt 10485760 ]; then
            log "Compressing large backup file..."
            gzip "$filename"
            filename="${filename}.gz"
            file_size=$(du -h "$filename" | cut -f1)
            log "Backup compressed: $(basename "$filename") ($file_size)"
        fi
        
        echo "$filename"  # Return filename for rotation function
    else
        log "ERROR: Backup failed"
        rm -f "$filename"  # Clean up partial file
        unset PGPASSWORD
        exit 1
    fi
    
    unset PGPASSWORD
}

# Function to rotate backups
rotate_backups() {
    local backup_type="$1"
    
    log "Starting backup rotation for $backup_type backups"
    
    cd "$BACKUP_DIR"
    
    case "$backup_type" in
        "daily")
            # Keep only last N daily backups
            ls -t privacyidea_daily_*.sql* 2>/dev/null | tail -n +$((KEEP_DAILY + 1)) | xargs -r rm -f
            local kept=$(ls privacyidea_daily_*.sql* 2>/dev/null | wc -l)
            log "Daily rotation completed: keeping $kept backups"
            ;;
        "weekly")
            # Keep only last N weekly backups
            ls -t privacyidea_weekly_*.sql* 2>/dev/null | tail -n +$((KEEP_WEEKLY + 1)) | xargs -r rm -f
            local kept=$(ls privacyidea_weekly_*.sql* 2>/dev/null | wc -l)
            log "Weekly rotation completed: keeping $kept backups"
            ;;
        "monthly")
            # Keep only last N monthly backups
            ls -t privacyidea_monthly_*.sql* 2>/dev/null | tail -n +$((KEEP_MONTHLY + 1)) | xargs -r rm -f
            local kept=$(ls privacyidea_monthly_*.sql* 2>/dev/null | wc -l)
            log "Monthly rotation completed: keeping $kept backups"
            ;;
    esac
}

# Function to send notification (can be customized)
send_notification() {
    local status="$1"
    local message="$2"
    
    # Add your notification logic here (email, Slack, etc.)
    # For now, just log
    log "NOTIFICATION [$status]: $message"
}

# Function to get backup statistics
show_backup_stats() {
    log "=== Backup Statistics ==="
    
    local total_backups=$(ls "$BACKUP_DIR"/privacyidea_*.sql* 2>/dev/null | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    
    log "Total backups: $total_backups"
    log "Total backup size: $total_size"
    
    if [ $total_backups -gt 0 ]; then
        log "Latest backups:"
        ls -lath "$BACKUP_DIR"/privacyidea_*.sql* 2>/dev/null | head -5 | while read line; do
            log "  $line"
        done
    fi
    
    log "=========================="
}

# Main execution
main() {
    local backup_type="${1:-daily}"
    
    log "========================================"
    log "Starting automated backup process"
    log "Backup type: $backup_type"
    log "========================================"
    
    # Pre-flight checks
    check_disk_space
    check_services
    load_env
    
    # Create backup
    local backup_file
    if backup_file=$(create_backup "$backup_type"); then
        log "Backup creation successful: $(basename "$backup_file")"
        
        # Rotate old backups
        rotate_backups "$backup_type"
        
        # Show statistics
        show_backup_stats
        
        # Send success notification
        send_notification "SUCCESS" "Backup completed: $(basename "$backup_file")"
        
        log "Automated backup process completed successfully"
        exit 0
        
    else
        log "ERROR: Backup creation failed"
        send_notification "ERROR" "Backup failed for $backup_type"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-daily}" in
    "daily"|"weekly"|"monthly")
        main "$1"
        ;;
    *)
        echo "Usage: $0 [daily|weekly|monthly]"
        echo "Default: daily"
        exit 1
        ;;
esac
