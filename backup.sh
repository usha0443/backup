#!/bin/bash
# =====================================================
# Automated Backup System
# Author: Suresh
# =====================================================

set -e

LOG_FILE="backup.log"
LOCK_FILE="/tmp/backup.lock"
CONFIG_FILE="backup.config"
DRY_RUN=0

# -----------------------------------------------------
# Logging function
# -----------------------------------------------------
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $level: $message" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------
# Load configuration
# -----------------------------------------------------
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log "WARN" "Config file not found, using defaults."
        BACKUP_DESTINATION="/tmp/backups"
        EXCLUDE_PATTERNS=".git,node_modules,.cache"
        DAILY_KEEP=7
        WEEKLY_KEEP=4
        MONTHLY_KEEP=3
        return
    fi

    # ✅ FIXED: valid while loop to read config
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        export "$key"="$value"
    done < "$CONFIG_FILE"
}

# -----------------------------------------------------
# Parse arguments
# -----------------------------------------------------
parse_args() {
    if [ "$1" == "--dry-run" ]; then
        DRY_RUN=1
        shift
    fi

    SOURCE_DIR="$1"
    if [ -z "$SOURCE_DIR" ]; then
        log "ERROR" "Usage: $0 [--dry-run] <folder_to_backup>"
        exit 1
    fi

    if [ ! -d "$SOURCE_DIR" ]; then
        log "ERROR" "Source folder not found: $SOURCE_DIR"
        exit 1
    fi
}

# -----------------------------------------------------
# Create backup
# -----------------------------------------------------
create_backup() {
    TIMESTAMP=$(date +%Y-%m-%d-%H%M)
    BACKUP_FILE="backup-${TIMESTAMP}.tar.gz"
    DEST="$BACKUP_DESTINATION"

    mkdir -p "$DEST"

    local exclude_args=()
    IFS=',' read -ra patterns <<< "$EXCLUDE_PATTERNS"
    for pattern in "${patterns[@]}"; do
        exclude_args+=(--exclude="$pattern")
    done

    if [ "$DRY_RUN" -eq 1 ]; then
        log "INFO" "Dry-run: Would create backup $DEST/$BACKUP_FILE from $SOURCE_DIR"
    else
        log "INFO" "Creating backup: $DEST/$BACKUP_FILE"
        tar -czf "$DEST/$BACKUP_FILE" "${exclude_args[@]}" "$SOURCE_DIR"
        sha256sum "$DEST/$BACKUP_FILE" > "$DEST/$BACKUP_FILE.sha256"
        log "SUCCESS" "Backup created and checksum saved."
    fi
}

# -----------------------------------------------------
# Main program
# -----------------------------------------------------
main() {
    load_config
    parse_args "$@"
    create_backup
}

main "$@"