#!/bin/bash

SOURCE_DIR="$HOME/linux-projects/automated-cloud-backup-pipeline/source"

BACKUP_DIR="$HOME/linux-projects/automated-cloud-backup-pipeline/backups"

LOG_DIR="$HOME/linux-projects/automated-cloud-backup-pipeline/logs"

LOG_FILE="$LOG_DIR/backup.log"

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

S3_BUCKET="s3://kavya-linux-backup-2026"
AWS_PROFILE="backup-user"

RETENTION_COUNT=7

MAX_RETRIES=3
RETRY_DELAY=5

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR" "$LOG_DIR"


# Check source directory

if [ ! -d "$SOURCE_DIR" ]; then
    log "ERROR: Source directory not found: $SOURCE_DIR"
    exit 1
fi


# Check AWS CLI

if ! command -v aws >/dev/null 2>&1; then
    log "ERROR: AWS CLI is not installed or not in PATH"
    exit 1
fi


# Check AWS authentication

if ! aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1; then
    log "ERROR: AWS authentication failed"
    exit 1
fi


# Create backup

tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

STATUS=$?

if [ "$STATUS" -eq 0 ]; then

    log "Backup successful: $BACKUP_FILE"

    # S3 upload with retry

    ATTEMPT=1
    UPLOAD_STATUS=1

    while [ "$ATTEMPT" -le "$MAX_RETRIES" ]; do

        log "S3 upload attempt $ATTEMPT/$MAX_RETRIES: $BACKUP_FILE"

        aws s3 cp "$BACKUP_FILE" "$S3_BUCKET/" --profile "$AWS_PROFILE"

        UPLOAD_STATUS=$?

        if [ "$UPLOAD_STATUS" -eq 0 ]; then
            break
        fi

        if [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; then
            log "S3 upload failed. Retrying in $RETRY_DELAY seconds..."
            sleep "$RETRY_DELAY"
        fi

        ATTEMPT=$((ATTEMPT + 1))

    done


    # Check final upload status

    if [ "$UPLOAD_STATUS" -eq 0 ]; then

        log "S3 upload successful: $BACKUP_FILE"

        # Verify backup exists in S3

        if aws s3 ls "$S3_BUCKET/$(basename "$BACKUP_FILE")" --profile "$AWS_PROFILE" >/dev/null 2>&1; then

            log "S3 verification successful: $(basename "$BACKUP_FILE")"

        else

            log "ERROR: S3 verification failed: $(basename "$BACKUP_FILE")"
            exit 1

        fi

    else

        log "ERROR: S3 upload failed after $MAX_RETRIES attempts: $BACKUP_FILE"
        exit 1

    fi

else

    log "ERROR: Backup creation failed"
    exit 1

fi


# Keep only the latest 7 local backups

OLD_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "backup_*.tar.gz" | sort | head -n -"$RETENTION_COUNT")

if [ -n "$OLD_BACKUPS" ]; then

    echo "$OLD_BACKUPS" | while read -r OLD_BACKUP; do

        rm -- "$OLD_BACKUP"

        log "Removed old backup: $OLD_BACKUP"

    done

fi
