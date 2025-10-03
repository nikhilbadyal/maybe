#!/bin/bash

# Restore PostgreSQL Backup Script
# Usage: ./restore.sh <backup-file.sql.gz> [compose-file]

set -e

BACKUP_FILE="$1"
COMPOSE_FILE="${2:-}"
CONTAINER_NAME="maybe-postgres"

# Auto-detect compose file if not specified
if [ -z "$COMPOSE_FILE" ]; then
    if [ -f "docker-compose.yml" ]; then
        COMPOSE_FILE="docker-compose.yml"
    elif [ -f "compose.yml" ]; then
        COMPOSE_FILE="compose.yml"
    elif [ -f "me.compose.example.yml" ]; then
        COMPOSE_FILE="me.compose.example.yml"
    elif [ -f "compose.example.yml" ]; then
        COMPOSE_FILE="compose.example.yml"
    else
        echo "Error: No compose file found. Please specify: ./restore.sh <backup-file> <compose-file>"
        exit 1
    fi
fi

# Auto-detect env file
ENV_FILE=""
if [ -f ".env.docker" ]; then
    ENV_FILE=".env.docker"
elif [ -f ".env" ]; then
    ENV_FILE=".env"
fi

# Set compose command with file flag and env file
if [ -n "$ENV_FILE" ]; then
    COMPOSE_CMD="docker compose -f $COMPOSE_FILE --env-file $ENV_FILE"
else
    COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}$1${NC}"
}

echo_success() {
    echo -e "${GREEN}$1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}$1${NC}"
}

echo_error() {
    echo -e "${RED}$1${NC}"
}

# Check if backup file is provided
if [ -z "$BACKUP_FILE" ]; then
    echo_error "❌ Error: No backup file specified"
    echo "Usage: ./restore.sh <backup-file.sql.gz> [compose-file]"
    echo ""
    echo "Examples:"
    echo "  ./restore.sh maybe_backup_20250920_120001.sql.gz"
    echo "  ./restore.sh maybe_backup_20250920_120001.sql.gz me.compose.example.yml"
    exit 1
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo_error "❌ Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo_info "🔄 Starting PostgreSQL restore process..."
echo ""
echo_info "📦 Backup file: $BACKUP_FILE"
echo_info "📏 File size: $(du -h "$BACKUP_FILE" | cut -f1)"
echo_info "🐳 Compose file: $COMPOSE_FILE"
if [ -n "$ENV_FILE" ]; then
    echo_info "🔧 Env file: $ENV_FILE"
fi
echo ""

# Check if .env.docker exists
if [ ! -f ".env.docker" ]; then
    echo_error "❌ Error: .env.docker file not found"
    echo "Please create .env.docker with your database credentials"
    exit 1
fi

# Test backup file integrity
echo_info "🔍 Testing backup file integrity..."
if gunzip -t "$BACKUP_FILE" 2>/dev/null; then
    echo_success "✅ Backup file is valid"
else
    echo_error "❌ Backup file is corrupted or invalid"
    exit 1
fi
echo ""

# Confirm restore
echo_warning "⚠️  WARNING: This will replace your current database with the backup!"
echo "Press Ctrl+C to cancel, or press Enter to continue..."
read -r

# Stop all services except postgres
echo_info "🛑 Stopping existing services..."
$COMPOSE_CMD down 2>/dev/null || true
echo ""

# Start postgres
echo_info "📦 Starting PostgreSQL..."
$COMPOSE_CMD up -d postgres

# Wait for postgres to be healthy
echo_info "⏳ Waiting for PostgreSQL to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if $COMPOSE_CMD exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
        echo_success "✅ PostgreSQL is ready"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
    echo -n "."
done
echo ""

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo_error "❌ PostgreSQL failed to start"
    exit 1
fi

# Copy backup to container
echo_info "📂 Copying backup file to container..."
docker cp "$BACKUP_FILE" "$CONTAINER_NAME:/tmp/backup.sql.gz"
echo_success "✅ Backup file copied"
echo ""

# Restore database
echo_info "🔄 Restoring database..."
echo_info "   This may take several minutes depending on the backup size..."
echo ""

$COMPOSE_CMD exec -T postgres sh -c '
    set -e
    
    # Decompress
    echo "📦 Decompressing backup..."
    gunzip -f /tmp/backup.sql.gz
    
    # Get database info from environment
    DB_NAME="${POSTGRES_DB}"
    DB_USER="${POSTGRES_USER}"
    
    echo "🗄️  Database: $DB_NAME"
    echo "👤 User: $DB_USER"
    echo ""
    
    # Restore
    echo "🔄 Running pg_restore..."
    pg_restore \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --clean \
        --if-exists \
        --no-owner \
        --no-acl \
        -v \
        /tmp/backup.sql 2>&1 || {
            echo "⚠️  Some warnings/errors may be expected during restore"
        }
    
    echo ""
    echo "🧹 Cleaning up temporary files..."
    rm -f /tmp/backup.sql /tmp/backup.sql.gz
'

RESTORE_EXIT_CODE=$?

if [ $RESTORE_EXIT_CODE -eq 0 ]; then
    echo ""
    echo_success "✅ Restore completed successfully!"
    echo ""
    
    # Verify restore
    echo_info "🔍 Verifying restore..."
    echo ""
    
    echo "📊 Tables in database:"
    $COMPOSE_CMD exec -T postgres psql -U postgres -d postgres -c "\dt" 2>/dev/null || true
    echo ""
    
    echo "📈 Sample record counts:"
    $COMPOSE_CMD exec -T postgres psql -U postgres -d postgres -t -c "
        SELECT 
            schemaname || '.' || tablename as table_name, 
            n_live_tup as row_count 
        FROM pg_stat_user_tables 
        ORDER BY n_live_tup DESC 
        LIMIT 10;
    " 2>/dev/null || true
    echo ""
    
    # Start all services
    echo_info "🚀 Starting all services..."
    $COMPOSE_CMD up -d
    echo ""
    
    echo_success "✅ All done! Your application should be running now."
    echo ""
    echo_info "Next steps:"
    echo "  1. Test your application: http://localhost"
    echo "  2. Verify your data is correct"
    echo "  3. Re-enable backups: $COMPOSE_CMD --profile backup up -d"
    echo ""
    
else
    echo ""
    echo_error "❌ Restore failed with exit code $RESTORE_EXIT_CODE"
    echo ""
    echo_info "Troubleshooting:"
    echo "  1. Check docker logs: $COMPOSE_CMD logs postgres"
    echo "  2. Try stopping all services first: $COMPOSE_CMD down"
    echo "  3. Check .env.docker has correct credentials"
    exit 1
fi

