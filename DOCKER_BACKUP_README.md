# 🐳 Docker PostgreSQL Backup to Cloudflare R2

Fully containerized backup solution using your existing Cloudflare R2 configuration!

## 📦 What's Included

- **backup.sh** - Portable backup script
- **Docker service** - Runs in your existing compose stack
- **Alpine Linux** - Lightweight container with PostgreSQL + AWS CLI
- **Cloudflare R2** - Direct upload using your existing R2 credentials

## 🚀 Quick Setup

### 1. Verify Your Configuration

Your backup uses the existing Cloudflare R2 credentials from your `.env.docker`:

```bash
# Check if all required variables are configured
./verify-backup-config.sh
```

The script will verify these existing variables from your `.env.docker`:
- `DB_HOST`, `DB_PORT` (Database connection)
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` (Database credentials)
- `CLOUDFLARE_ACCESS_KEY_ID`, `CLOUDFLARE_SECRET_ACCESS_KEY` (R2 credentials)
- `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_BUCKET` (R2 endpoint & bucket)
- `APPRISE_URL` (Optional - for notifications)

### 2. Start Backup Service

```bash
# Start backup service
docker-compose --profile backup up -d

# Check it's running
docker-compose ps
```

### 3. Test Backup

```bash
# Run manual backup
docker-compose exec backup /backup.sh
```

### 4. Automated Backups (Built-in)

The backup container has **built-in cron scheduling** - no external cron needed!

- ✅ **Schedule**: Every 4 hours (0:00, 4:00, 8:00, 12:00, 16:00, 20:00 UTC)
- ✅ **Automatic**: Starts when you run `docker-compose --profile backup up -d`
- ✅ **Self-contained**: Container manages its own schedule
- ✅ **Integrity validation**: Verifies backups before/after upload
- ✅ **Auto-cleanup**: Keeps only last 7 days of backups in R2
- ✅ **Notifications**: Success/failure alerts via Apprise (optional)

### 5. Notifications Setup (Optional)

Get notified when backups succeed or fail:

**Add to your `.env.docker`:**
```bash
# Apprise notification URL
APPRISE_URL=https://discord.com/api/webhooks/your-webhook-id/your-token
```

**Apprise supports:**
- 📱 **Discord** webhooks
- 💬 **Slack** webhooks
- 📧 **Email** (SMTP)
- 📲 **SMS** (Twilio)
- 🔔 **Push notifications**
- And many more!

**Notification Types:**
- 🔄 **Start**: Backup process started
- ✅ **Success**: Backup completed successfully with details
- ❌ **Failure**: Backup failed with error details
- ⚠️ **Warnings**: Upload verification issues

**Example Success Notification:**
```
✅ Backup Successful
Backup completed successfully
📦 File: maybe_backup_20241201_080000.sql.gz
📏 Size: 1.2G
🪣 Bucket: finance
🧹 Cleaned up old backups
```

## 🎯 How It Works

1. **Backup Service**: Alpine container with PostgreSQL client + AWS CLI + Cron
2. **Schedule**: Automatic backups every 4 hours (0, 4, 8, 12, 16, 20 UTC)
3. **Environment Variables**: Uses all your existing `.env.docker` variables (no hardcoding!)
4. **Network Access**: Connects to postgres container via Docker network
5. **Integrity Validation**: Verifies backup before upload and after
6. **Direct Upload**: Streams backup directly to R2 (no local storage)
7. **Automatic Cleanup**: Local temp files + old R2 backups (keeps last 7 days)

## 📁 Files Created

- `backup.sh` - Main backup script (uses existing env vars)
- `verify-backup-config.sh` - Verification script for existing credentials
- `DOCKER_BACKUP_README.md` - This documentation

## 🔧 Manual Usage

```bash
# Start backup service
docker-compose --profile backup up -d

# Run backup
docker-compose exec backup /backup.sh

# View logs
docker-compose logs backup

# Stop backup service
docker-compose --profile backup down
```

## ✅ Perfect for Your Setup!

Your environment already has all the required variables configured:

- ✅ `DB_HOST`, `DB_PORT` - Database connection (postgres:5432)
- ✅ `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` - Database credentials
- ✅ `CLOUDFLARE_ACCESS_KEY_ID` - R2 access key
- ✅ `CLOUDFLARE_SECRET_ACCESS_KEY` - R2 secret key
- ✅ `CLOUDFLARE_ACCOUNT_ID` - Your account ID
- ✅ `CLOUDFLARE_BUCKET` - finance (your bucket)

## 🚀 Ready to Use!

Just run:
```bash
# Start backup service
docker-compose --profile backup up -d

# Test backup
docker-compose exec backup /backup.sh
```

Your PostgreSQL database will be automatically backed up to Cloudflare R2 **every 4 hours** with automatic cleanup (keeps last 7 days only) and notifications! 🧹📱
