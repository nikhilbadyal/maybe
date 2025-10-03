# 🔄 Restore PostgreSQL Backup

## Prerequisites

- Docker and Docker Compose installed
- Your backup file: `maybe_backup_20250920_120001.sql.gz`
- Your `.env.docker` file with database credentials

## 🚀 Restore Steps

### 1. Start Fresh PostgreSQL Database

```bash
# Start only postgres service
docker compose up -d postgres

# Wait for postgres to be healthy
docker compose ps postgres
```

### 2. Copy Backup File into Container

```bash
# Copy your backup file to the postgres container
docker cp maybe_backup_20250920_120001.sql.gz maybe-postgres:/tmp/
```

### 3. Restore Database

```bash
# Execute restore inside postgres container
docker compose exec postgres sh -c '
  # Decompress the backup
  gunzip /tmp/maybe_backup_20250920_120001.sql.gz
  
  # Restore the database
  # Note: The backup is in custom format, so we use pg_restore
  pg_restore \
    -U ${POSTGRES_USER} \
    -d ${POSTGRES_DB} \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl \
    /tmp/maybe_backup_20250920_120001.sql
'
```

### 4. Verify Restore

```bash
# Check if tables exist
docker compose exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\dt"

# Check record counts
docker compose exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "
  SELECT 'accounts' as table_name, COUNT(*) FROM accounts
  UNION ALL
  SELECT 'users', COUNT(*) FROM users
  UNION ALL
  SELECT 'entries', COUNT(*) FROM entries;
"
```

### 5. Start All Services

```bash
# Start all services
docker compose up -d

# Check all services are running
docker compose ps
```

## 🛠️ Alternative: One-Step Restore Script

Create a restore script for easier restoration:

```bash
#!/bin/bash
# restore.sh

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./restore.sh <backup-file.sql.gz>"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "🔄 Starting restore process..."

# Start postgres
echo "📦 Starting PostgreSQL..."
docker compose up -d postgres

# Wait for postgres to be healthy
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 10

# Copy backup to container
echo "📂 Copying backup file to container..."
docker cp "$BACKUP_FILE" maybe-postgres:/tmp/backup.sql.gz

# Restore
echo "🔄 Restoring database..."
docker compose exec -T postgres sh -c '
  gunzip -f /tmp/backup.sql.gz
  pg_restore \
    -U ${POSTGRES_USER} \
    -d ${POSTGRES_DB} \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl \
    -v \
    /tmp/backup.sql
'

RESTORE_EXIT_CODE=$?

if [ $RESTORE_EXIT_CODE -eq 0 ]; then
  echo "✅ Restore completed successfully!"
  echo ""
  echo "🔍 Verifying restore..."
  docker compose exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\dt"
  echo ""
  echo "🚀 Starting all services..."
  docker compose up -d
  echo ""
  echo "✅ All done! Your application should be running now."
else
  echo "❌ Restore failed with exit code $RESTORE_EXIT_CODE"
  exit 1
fi

# Cleanup
docker compose exec postgres rm -f /tmp/backup.sql /tmp/backup.sql.gz
```

Make it executable:
```bash
chmod +x restore.sh
```

Run it:
```bash
./restore.sh maybe_backup_20250920_120001.sql.gz
```

## 🔍 Troubleshooting

### Issue: "database is being accessed by other users"

```bash
# Stop all services first
docker compose down

# Start only postgres
docker compose up -d postgres

# Try restore again
```

### Issue: "permission denied" or "must be owner"

The restore script uses `--no-owner --no-acl` flags to avoid permission issues. If you still encounter problems:

```bash
# Connect as superuser and grant permissions
docker compose exec postgres psql -U postgres -d ${POSTGRES_DB} -c "
  GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${POSTGRES_USER};
  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${POSTGRES_USER};
"
```

### Issue: Backup file is corrupted

```bash
# Test if backup file is valid
gunzip -t maybe_backup_20250920_120001.sql.gz

# If corrupted, check if you have backups in Cloudflare R2
# You can download from R2 using:
aws s3 cp s3://${CLOUDFLARE_BUCKET}/maybe_backup_20250920_120001.sql.gz . \
  --endpoint-url="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"
```

## 📥 Restore from Cloudflare R2

If you have backups in R2 but not locally:

```bash
# List available backups
aws s3 ls s3://${CLOUDFLARE_BUCKET}/ \
  --endpoint-url="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com" \
  | grep maybe_backup

# Download specific backup
aws s3 cp s3://${CLOUDFLARE_BUCKET}/maybe_backup_20250920_120001.sql.gz . \
  --endpoint-url="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"

# Then use restore script
./restore.sh maybe_backup_20250920_120001.sql.gz
```

## ✅ Post-Restore Checklist

- [ ] Verify all tables exist: `docker compose exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "\dt"`
- [ ] Check record counts match expectations
- [ ] Test login to the application
- [ ] Verify critical data (accounts, transactions, etc.)
- [ ] Re-enable backup service: `docker compose --profile backup up -d`

## 🎯 Quick Reference

```bash
# Start postgres only
docker compose up -d postgres

# Copy backup to container
docker cp backup.sql.gz maybe-postgres:/tmp/

# Restore
docker compose exec postgres sh -c 'gunzip /tmp/backup.sql.gz && pg_restore -U $POSTGRES_USER -d $POSTGRES_DB --clean --if-exists --no-owner --no-acl /tmp/backup.sql'

# Start all services
docker compose up -d
```

