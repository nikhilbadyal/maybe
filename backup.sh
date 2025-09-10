#!/bin/sh

# Portable PostgreSQL Backup to Cloudflare R2
# Runs inside Docker container with all tools included

set -e

# Database config (using environment variables)
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB}"
DB_USER="${POSTGRES_USER}"
DB_PASSWORD="${POSTGRES_PASSWORD}"

# Cloudflare R2 config (using existing env vars)
R2_ACCESS_KEY="${CLOUDFLARE_ACCESS_KEY_ID}"
R2_SECRET_KEY="${CLOUDFLARE_SECRET_ACCESS_KEY}"
R2_ENDPOINT="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"
R2_BUCKET="${CLOUDFLARE_BUCKET}"

# Timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="maybe_backup_${TIMESTAMP}.sql.gz"

# Validation status
VALIDATION_PASSED=false

# Notification functions
send_notification() {
    local title="$1"
    local message="$2"
    local status="$3"

    if [ -n "${APPRISE_URL}" ]; then
        echo "📤 Sending $status notification..."
        if apprise -t "$title" -b "$message" "${APPRISE_URL}" >/dev/null 2>&1; then
            echo "✅ Notification sent"
        else
            echo "⚠️  Notification failed to send"
        fi
    else
        echo "ℹ️  No APPRISE_URL configured - skipping notification"
    fi
}

echo "🔄 Starting PostgreSQL backup to R2..."
echo "📅 $(date)"

# Send start notification
send_notification "🔄 Backup Started" "PostgreSQL backup process started at $(date)" "info"

# Validate config
if [ -z "$R2_ACCESS_KEY" ] || [ -z "$R2_SECRET_KEY" ] || [ -z "$R2_ENDPOINT" ]; then
    echo "❌ ERROR: R2 credentials not configured"
    echo "Set: R2_ACCESS_KEY, R2_SECRET_KEY, R2_ENDPOINT, R2_BUCKET"
    send_notification "❌ Backup Failed" "Configuration error: R2 credentials not configured" "error"
    exit 1
fi

# Test database connection
echo "🔍 Testing database connection..."
if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    echo "❌ ERROR: Cannot connect to PostgreSQL"
    send_notification "❌ Backup Failed" "Database connection failed to $DB_HOST:$DB_PORT" "error"
    exit 1
fi
echo "✅ Database connection OK"

# Create backup
echo "💾 Creating backup..."
echo "🔍 Debug: pg_dump command: pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME --no-password --compress=9 --format=custom"

# Check available disk space before backup
echo "💾 Available disk space in /tmp:"
df -h /tmp 2>/dev/null || echo "Cannot check disk space"

# Run pg_dump with error handling
# Use a temp file to capture stderr while piping stdout to gzip
PG_DUMP_STDERR=$(mktemp)
PGPASSWORD="$DB_PASSWORD" pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --no-password \
    --compress=9 \
    --format=custom \
    2>"$PG_DUMP_STDERR" | gzip > "/tmp/$BACKUP_FILE"

PG_DUMP_EXIT_CODE=$?
PG_DUMP_OUTPUT=$(cat "$PG_DUMP_STDERR")
rm -f "$PG_DUMP_STDERR"

if [ $PG_DUMP_EXIT_CODE -ne 0 ]; then
    echo "❌ ERROR: pg_dump failed with exit code $PG_DUMP_EXIT_CODE"
    echo "🔍 pg_dump stderr: $PG_DUMP_OUTPUT"
    send_notification "❌ Backup Failed" "pg_dump failed with exit code $PG_DUMP_EXIT_CODE" "error"
    rm -f "/tmp/$BACKUP_FILE"
    exit 1
fi

# Verify gzip completed successfully
if ! gzip -t "/tmp/$BACKUP_FILE" 2>/dev/null; then
    echo "❌ ERROR: gzip compression failed"
    send_notification "❌ Backup Failed" "gzip compression failed" "error"
    rm -f "/tmp/$BACKUP_FILE"
    exit 1
fi

echo "✅ Backup created: $BACKUP_FILE"

# Decompress temporarily for validation
echo "🔄 Decompressing for validation..."
BACKUP_UNCOMPRESSED="/tmp/${BACKUP_FILE%.gz}"
if ! gunzip -c "/tmp/$BACKUP_FILE" > "$BACKUP_UNCOMPRESSED" 2>/dev/null; then
    echo "❌ ERROR: Failed to decompress backup for validation"
    send_notification "❌ Backup Failed" "Decompression for validation failed" "error"
    rm -f "/tmp/$BACKUP_FILE"
    exit 1
fi

# Validate backup integrity before upload
echo "🔍 Validating backup integrity..."
if [ ! -f "/tmp/$BACKUP_FILE" ]; then
    echo "❌ ERROR: Backup file was not created"
    send_notification "❌ Backup Failed" "Backup file creation failed" "error"
    exit 1
fi

# Check file size
BACKUP_SIZE=$(stat -c%s "/tmp/$BACKUP_FILE" 2>/dev/null || stat -f%z "/tmp/$BACKUP_FILE" 2>/dev/null || echo "0")
if [ "$BACKUP_SIZE" -lt 1000 ]; then  # Less than 1KB is suspicious
    echo "❌ ERROR: Backup file is too small (${BACKUP_SIZE} bytes) - likely corrupted"
    send_notification "❌ Backup Failed" "Backup file too small: ${BACKUP_SIZE} bytes" "error"
    rm -f "/tmp/$BACKUP_FILE"
    exit 1
fi

# Test backup structure (without restoring)
echo "🔧 Testing backup structure..."

# Debug: Check if file exists and is readable
if [ ! -r "/tmp/$BACKUP_FILE" ]; then
    echo "❌ ERROR: Backup file is not readable"
    ls -la "/tmp/$BACKUP_FILE" 2>/dev/null || echo "File does not exist or permission denied"
    send_notification "❌ Backup Failed" "Backup file is not readable" "error"
    rm -f "/tmp/$BACKUP_FILE"
    exit 1
fi

# Debug: Check file size
BACKUP_SIZE_BYTES=$(stat -c%s "/tmp/$BACKUP_FILE" 2>/dev/null || stat -f%z "/tmp/$BACKUP_FILE" 2>/dev/null || echo "0")
echo "📏 Backup file size: $BACKUP_SIZE_BYTES bytes"

# Debug: Check file type
file "/tmp/$BACKUP_FILE" 2>/dev/null || echo "file command not available"

# Debug: Test pg_restore with verbose output
echo "🔍 Running: pg_restore --list $BACKUP_UNCOMPRESSED"
PG_RESTORE_OUTPUT=$(pg_restore --list "$BACKUP_UNCOMPRESSED" 2>&1)
PG_RESTORE_EXIT_CODE=$?

echo "🔍 pg_restore exit code: $PG_RESTORE_EXIT_CODE"
echo "🔍 pg_restore output length: ${#PG_RESTORE_OUTPUT} characters"

if [ $PG_RESTORE_EXIT_CODE -ne 0 ]; then
    echo "❌ ERROR: Backup file structure validation failed"
    echo "🔍 Debug information:"
    echo "   Exit code: $PG_RESTORE_EXIT_CODE"
    echo "   pg_restore output: $PG_RESTORE_OUTPUT"
    echo "   Compressed file details:"
    ls -la "/tmp/$BACKUP_FILE" 2>/dev/null || echo "   Cannot get compressed file details"
    echo "   Uncompressed file details:"
    ls -la "$BACKUP_UNCOMPRESSED" 2>/dev/null || echo "   Cannot get uncompressed file details"
    echo "   Disk space:"
    df -h /tmp 2>/dev/null || echo "   Cannot check disk space"

    send_notification "❌ Backup Failed" "Backup structure validation failed\nExit code: $PG_RESTORE_EXIT_CODE\nDetails: $PG_RESTORE_OUTPUT" "error"
    rm -f "/tmp/$BACKUP_FILE" "$BACKUP_UNCOMPRESSED"
    exit 1
else
    echo "✅ Backup structure validation passed"
    # Clean up uncompressed file after successful validation
    rm -f "$BACKUP_UNCOMPRESSED"
fi

echo "✅ Backup validation passed"
VALIDATION_PASSED=true

# Upload to R2
echo "☁️  Uploading to R2..."
echo "🔍 Debug: Upload destination: s3://$R2_BUCKET/$BACKUP_FILE"
echo "🔍 Debug: Endpoint: $R2_ENDPOINT"

# Capture AWS CLI output for debugging
UPLOAD_OUTPUT=$(AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
    aws s3 cp "/tmp/$BACKUP_FILE" "s3://$R2_BUCKET/$BACKUP_FILE" \
    --endpoint-url="$R2_ENDPOINT" \
    --no-progress \
    2>&1)

UPLOAD_EXIT_CODE=$?
if [ $UPLOAD_EXIT_CODE -ne 0 ]; then
    echo "❌ ERROR: Upload failed with exit code $UPLOAD_EXIT_CODE"
    echo "🔍 AWS CLI output: $UPLOAD_OUTPUT"
    send_notification "❌ Backup Failed" "Upload failed with exit code $UPLOAD_EXIT_CODE\nDetails: $UPLOAD_OUTPUT" "error"
    # Don't exit here - backup file is created, just upload failed
    # We'll still try to verify if it was uploaded despite the error
else
    echo "✅ Upload completed"
fi

# Get file size
SIZE=$(du -h "/tmp/$BACKUP_FILE" | cut -f1)

# Verify upload was successful
echo "🔍 Verifying upload..."
UPLOADED_SIZE=$(AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
    aws s3 ls "s3://$R2_BUCKET/$BACKUP_FILE" \
    --endpoint-url="$R2_ENDPOINT" 2>/dev/null | awk '{print $3}')

if [ -z "$UPLOADED_SIZE" ] || [ "$UPLOADED_SIZE" -ne "$BACKUP_SIZE" ]; then
    echo "❌ ERROR: Upload verification failed"
    echo "Local size: $BACKUP_SIZE bytes"
    echo "Remote size: ${UPLOADED_SIZE:-unknown} bytes"
    send_notification "⚠️ Upload Verification Failed" "Backup uploaded but size verification failed\nLocal: $BACKUP_SIZE bytes\nRemote: ${UPLOADED_SIZE:-unknown} bytes\nFile: $BACKUP_FILE" "warning"
    # Don't exit here - backup is created, just upload verification failed
else
    echo "✅ Upload verification passed"
fi

# Cleanup local temp file
rm -f "/tmp/$BACKUP_FILE"

# Clean up old backups (keep only last 7 days) - only if validation passed
if [ "$VALIDATION_PASSED" = true ]; then
    echo "🧹 Cleaning up old backups (keeping last 7 days)..."
    echo "🔍 Debug: Listing files in bucket $R2_BUCKET"

# List all backup files in R2 bucket and delete old ones
CURRENT_DATE=$(date +%Y%m%d)
# Calculate 7 days ago (604800 seconds = 7 days)
CURRENT_SECONDS=$(date +%s)
SEVEN_DAYS_SECONDS=$((CURRENT_SECONDS - 604800))
SEVEN_DAYS_AGO=$(date -d "@$SEVEN_DAYS_SECONDS" +%Y%m%d 2>/dev/null || echo "00000000")

echo "📅 Current date: $CURRENT_DATE"
echo "📅 Deleting backups before: $SEVEN_DAYS_AGO"

# List all backup files and process them
BACKUP_FILES=$(AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
    aws s3 ls "s3://$R2_BUCKET/" \
    --endpoint-url="$R2_ENDPOINT" \
    --recursive 2>/dev/null | grep "maybe_backup_")

if [ -z "$BACKUP_FILES" ]; then
    echo "ℹ️  No backup files found in bucket"
else
    echo "📋 Found backup files:"
    echo "$BACKUP_FILES" | while read -r line; do
        FILE_NAME=$(echo "$line" | awk '{print $NF}')
        echo "   $FILE_NAME"
    done

    echo "$BACKUP_FILES" | while read -r line; do
        # Extract filename from the line (last field)
        FILE_NAME=$(echo "$line" | awk '{print $NF}')

        # Extract date from filename (format: maybe_backup_YYYYMMDD_HHMMSS.sql.gz)
        FILE_DATE=$(echo "$FILE_NAME" | sed 's/maybe_backup_\([0-9]\{8\}\)_.*\.sql\.gz/\1/')

        echo "🔍 Processing: $FILE_NAME (extracted date: $FILE_DATE)"

        # Check if we got a valid date (8 digits) and if it's older than 7 days
        if [ "${#FILE_DATE}" -eq 8 ] && [ "$FILE_DATE" -lt "$SEVEN_DAYS_AGO" ] 2>/dev/null; then
            # Additional validation: check if it contains only digits
            case "$FILE_DATE" in
                [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
                    echo "🗑️  Deleting old backup: $FILE_NAME (date: $FILE_DATE)"

                    # Delete the old backup
                    DELETE_OUTPUT=$(AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY" \
                        AWS_SECRET_ACCESS_KEY="$R2_SECRET_KEY" \
                        aws s3 rm "s3://$R2_BUCKET/$FILE_NAME" \
                        --endpoint-url="$R2_ENDPOINT" \
                        --quiet 2>&1)

                    DELETE_EXIT_CODE=$?
                    if [ $DELETE_EXIT_CODE -ne 0 ]; then
                        echo "⚠️  Failed to delete $FILE_NAME: $DELETE_OUTPUT"
                    else
                        echo "✅ Deleted: $FILE_NAME"
                    fi
                    ;;
                *)
                    echo "⚠️  Skipping invalid date format: $FILE_NAME (date: $FILE_DATE)"
                    ;;
            esac
        else
            echo "ℹ️  Keeping recent file: $FILE_NAME (date: $FILE_DATE)"
        fi
    done
fi

    echo "✅ Cleanup completed"
else
    echo "⚠️  Skipping cleanup due to validation failure"
fi

if [ "$VALIDATION_PASSED" = true ]; then
    echo "✅ Upload successful!"
    echo "📦 File: $BACKUP_FILE"
    echo "📏 Size: $SIZE"
    echo "🪣 Bucket: $R2_BUCKET"
    echo "🧹 Kept backups from last 7 days only"
    echo ""
    echo "🎉 Backup completed successfully!"

    # Send success notification
    send_notification "✅ Backup Successful" "Backup completed successfully\n📦 File: $BACKUP_FILE\n📏 Size: $SIZE\n🪣 Bucket: $R2_BUCKET\n🧹 Cleaned up old backups" "success"
else
    echo "❌ Backup validation failed - check logs above"
    echo "📦 File: $BACKUP_FILE (not uploaded due to validation failure)"

    # Send failure notification
    send_notification "❌ Backup Failed" "Backup validation failed - file not uploaded\n📦 File: $BACKUP_FILE\nCheck logs for details" "error"
    exit 1
fi
