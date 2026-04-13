# Borg Backup for Unraid with Borgmatic Docker Container

This setup uses the `b3vis/borgmatic` Docker container to automate BorgBackup on Unraid servers. Unlike traditional Borg setups, this approach uses Docker for persistence and borgmatic for easier configuration management.

## What It Does

This setup will:

1. Deploy a Docker container with BorgBackup and borgmatic pre-installed
2. Create secure encrypted backup repositories (local and/or remote)
3. Automatically run backups on your chosen schedule (via built-in cron)
4. Prune old backups based on retention policies
5. Persist all configuration across Unraid reboots
6. Optional: Send email notifications on success/failure

## Why Docker Container Instead of Scripts?

**Advantages over script-based approach:**
- **Automatic persistence** - Configuration stored in Docker appdata
- **No Unraid boot workarounds** - No need to modify `/boot/config/go`
- **Integrated scheduling** - Built-in cron, no User Scripts needed
- **Better configuration** - YAML format instead of shell scripts
- **More features** - Health checks, hooks, monitoring, email notifications
- **Easier updates** - Just update the Docker container
- **Unraid-native** - Managed through Unraid Docker GUI

## Prerequisites

- Unraid 6.x or later
- For remote backups:
  - SSH access to remote server
  - BorgBackup installed on remote server
  - SSH key authentication configured (passwordless)

## Quick Start

### Method A: Docker Compose (Recommended)

1. Copy all files to `/mnt/user/appdata/borgmatic/`:
   ```bash
   mkdir -p /mnt/user/appdata/borgmatic
   cd /mnt/user/appdata/borgmatic
   # Upload: docker-compose.yml, config.yaml, .env
   ```

2. Edit the `.env` file:
   ```bash
   nano .env
   # Set your passphrase and timezone
   ```

3. Edit `config.yaml`:
   ```bash
   nano config.yaml
   # Configure backup sources, repositories, and schedules
   ```

4. Deploy the container:
   ```bash
   docker-compose up -d
   ```

### Method B: Unraid Docker Template

1. In Unraid UI, go to **Docker** tab
2. Click **Add Container**
3. Use template settings from below
4. Configure paths and environment variables
5. Apply and start container

### Method C: Docker Command Line

```bash
docker run -d \
  --name=borgmatic \
  --restart=unless-stopped \
  -e TZ=America/New_York \
  -e BORG_PASSPHRASE=your-strong-passphrase \
  -v /mnt/user/appdata/borgmatic:/mnt/source:ro \
  -v /mnt/user/appdata/borgmatic/.config/borgmatic:/root/.config/borgmatic \
  -v /mnt/user/appdata/borgmatic/.ssh:/root/.ssh \
  -v /mnt/user/appdata/borgmatic/.cache/borg:/root/.cache/borg \
  -v /mnt/user/backups/borg-local:/mnt/borg-repository \
  b3vis/borgmatic:latest
```

## Directory Structure

After setup, your `/mnt/user/appdata/borgmatic/` will contain:

```
/mnt/user/appdata/borgmatic/
├── .config/
│   └── borgmatic/
│       └── config.yaml          # Main borgmatic configuration
├── .ssh/
│   ├── id_ed25519              # SSH private key (for remote backups)
│   ├── id_ed25519.pub          # SSH public key
│   └── known_hosts             # SSH host fingerprints
├── .cache/
│   └── borg/                   # Borg cache (speeds up backups)
├── docker-compose.yml          # Docker deployment configuration
└── .env                        # Environment variables (passphrase, etc.)
```

## Configuration Files

### 1. `config.yaml` - Borgmatic Configuration

This is your main configuration file. Key sections:

```yaml
repositories:
  - path: /mnt/borg-repository              # Local backup
  - path: ssh://user@backup-server.com/backups/borg-remote  # Remote backup

source_directories:
  - /mnt/source/appdata                     # Docker appdata
  - /mnt/source/documents                   # Your files

retention:
  keep_within: 14d
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 6

consistency:
  checks:
    - repository
    - archives

hooks:
  on_error:
    - echo "Backup failed!" | mail -s "Borg Backup Failed" you@email.com
```

See the included `config.yaml` for full example with comments.

### 2. `.env` - Environment Variables

```env
BORG_PASSPHRASE=your-strong-passphrase-here
TZ=America/New_York
```

**CRITICAL**: Keep this file secure (chmod 600) and back it up offline.

### 3. `docker-compose.yml` - Docker Configuration

Defines container settings, volume mounts, and environment variables.

## Setting Up SSH for Remote Backups

If you want to backup to a remote server via SSH:

### Step 1: Generate SSH Keys

```bash
# Create SSH directory
mkdir -p /mnt/user/appdata/borgmatic/.ssh

# Generate SSH key
ssh-keygen -t ed25519 -f /mnt/user/appdata/borgmatic/.ssh/id_ed25519 -N ""

# Set permissions
chmod 700 /mnt/user/appdata/borgmatic/.ssh
chmod 600 /mnt/user/appdata/borgmatic/.ssh/id_ed25519
chmod 644 /mnt/user/appdata/borgmatic/.ssh/id_ed25519.pub
```

### Step 2: Copy Key to Remote Server

```bash
# Copy public key to remote server
ssh-copy-id -i /mnt/user/appdata/borgmatic/.ssh/id_ed25519.pub user@backup-server.com

# Or manually:
cat /mnt/user/appdata/borgmatic/.ssh/id_ed25519.pub
# Then paste into ~/.ssh/authorized_keys on remote server
```

### Step 3: Test Connection

```bash
# Test SSH connection
ssh -i /mnt/user/appdata/borgmatic/.ssh/id_ed25519 user@backup-server.com "borg --version"
```

### Step 4: Add to Known Hosts

```bash
# Add remote host to known_hosts
ssh-keyscan backup-server.com >> /mnt/user/appdata/borgmatic/.ssh/known_hosts
```

## Scheduling Backups

Borgmatic uses **cron** for scheduling, configured directly in `config.yaml`:

```yaml
# Run daily at 2 AM
cron:
  - "0 2 * * *"

# Run twice per month (1st and 15th at 2 AM)
cron:
  - "0 2 1,15 * *"

# Run weekly on Sundays at 3 AM
cron:
  - "0 3 * * 0"
```

**Cron format**: `minute hour day month weekday`

Use [crontab.guru](https://crontab.guru/) to generate schedules.

## Volume Mounts Explained

| Container Path | Host Path | Purpose |
|---------------|-----------|---------|
| `/mnt/source:ro` | `/mnt/user/appdata` | Data to backup (read-only) |
| `/root/.config/borgmatic` | `/mnt/user/appdata/borgmatic/.config/borgmatic` | Borgmatic configuration |
| `/root/.ssh` | `/mnt/user/appdata/borgmatic/.ssh` | SSH keys for remote backups |
| `/root/.cache/borg` | `/mnt/user/appdata/borgmatic/.cache/borg` | Borg cache (speeds up backups) |
| `/mnt/borg-repository` | `/mnt/user/backups/borg-local` | Local backup repository |

**Important**:
- Add `:ro` (read-only) to source directories to prevent accidental modifications
- Map multiple source directories if backing up different locations
- For remote-only backups, you can skip the local repository mount

## Initial Setup and Testing

### 1. Initialize Repositories

After starting the container for the first time:

```bash
# Enter the container
docker exec -it borgmatic bash

# Initialize local repository
borgmatic init --encryption repokey

# Verify repository
borgmatic list
```

### 2. Run First Backup Manually

```bash
# Run backup manually
docker exec borgmatic borgmatic --verbosity 1 --stats

# Or from inside container:
docker exec -it borgmatic bash
borgmatic --verbosity 1 --stats
```

### 3. Check Logs

```bash
# View container logs
docker logs -f borgmatic

# View borgmatic logs from inside container
docker exec -it borgmatic cat /var/log/syslog
```

### 4. Export Repository Keys

**CRITICAL**: Export and save these keys offline!

```bash
# Export local repository key
docker exec borgmatic borg key export /mnt/borg-repository /tmp/borg-local-repo.key
docker cp borgmatic:/tmp/borg-local-repo.key ./borg-local-repo.key

# Export remote repository key (if using remote backups)
docker exec borgmatic borg key export ssh://user@server.com/path/to/repo /tmp/borg-remote-repo.key
docker cp borgmatic:/tmp/borg-remote-repo.key ./borg-remote-repo.key
```

**Store these keys safely!** You need BOTH the passphrase AND the key file to recover backups.

## Managing Backups

### Run Backup Manually

```bash
# Run backup now
docker exec borgmatic borgmatic --verbosity 1

# Run with statistics
docker exec borgmatic borgmatic --verbosity 1 --stats

# Dry run (test without creating backup)
docker exec borgmatic borgmatic --dry-run --verbosity 1
```

### List Backups

```bash
# List all archives
docker exec borgmatic borgmatic list

# List files in specific archive
docker exec borgmatic borgmatic list --archive "2024-01-15T02:00:00"
```

### Check Repository

```bash
# Verify repository integrity
docker exec borgmatic borgmatic check --verbosity 1
```

### Prune Old Backups

```bash
# Prune according to retention policy
docker exec borgmatic borgmatic prune --stats
```

### View Container Logs

```bash
# Follow logs in real-time
docker logs -f borgmatic

# View last 100 lines
docker logs --tail 100 borgmatic
```

### Check Backup Schedule

```bash
# View cron schedule inside container
docker exec borgmatic crontab -l
```

## Restoring from Backup

### List Available Archives

```bash
# Enter container
docker exec -it borgmatic bash

# List archives
borgmatic list
```

### Extract Entire Archive

```bash
# Extract to current directory
docker exec borgmatic borgmatic extract --archive "2024-01-15T02:00:00"

# Or specify destination (from inside container)
docker exec -it borgmatic bash
cd /mnt/restore
borgmatic extract --archive "2024-01-15T02:00:00"
```

### Extract Specific Files

```bash
# Extract specific path
docker exec borgmatic borgmatic extract \
  --archive "2024-01-15T02:00:00" \
  --path "mnt/source/appdata/plex"
```

### Mount Archive for Browsing

```bash
# Mount archive as filesystem
docker exec -it borgmatic bash
mkdir /mnt/borg-mount
borg mount /mnt/borg-repository::2024-01-15T02:00:00 /mnt/borg-mount
cd /mnt/borg-mount
# Browse and copy files
borg umount /mnt/borg-mount
```

### Restore on Different System

If your Unraid server failed, you need:
1. The repository (local backup drive or SSH access to remote)
2. The passphrase (from your `.env` file)
3. The repository key file (exported earlier)

```bash
# Install borgbackup on new system
apt-get install borgbackup

# Import the key
export BORG_PASSPHRASE='your-passphrase'
borg key import /path/to/repo /path/to/borg-repo.key

# List backups
borg list /path/to/repo

# Extract
mkdir /restore
cd /restore
borg extract /path/to/repo::2024-01-15T02:00:00
```

## Email Notifications

To receive email notifications when backups complete or fail:

### Option 1: Unraid Built-in Notifications

Configure in `config.yaml`:

```yaml
hooks:
  on_error:
    - /usr/local/emhttp/webGui/scripts/notify -s "Borg Backup Failed" -d "Check logs for details" -i alert
  after_backup:
    - /usr/local/emhttp/webGui/scripts/notify -s "Borg Backup Complete" -d "Backup finished successfully" -i normal
```

**Note**: This requires mounting Unraid's notification scripts into the container.

### Option 2: External SMTP

Configure in `config.yaml`:

```yaml
hooks:
  on_error:
    - echo "Backup failed on $(hostname)" | mail -s "Borg Backup FAILED" your-email@example.com
  after_backup:
    - echo "Backup completed successfully on $(hostname)" | mail -s "Borg Backup Success" your-email@example.com
```

Then configure SMTP in the container or use an external mail command.

### Option 3: Healthchecks.io / Uptime Kuma

```yaml
hooks:
  before_backup:
    - curl -fsS -m 10 --retry 5 https://hc-ping.com/your-uuid/start
  after_backup:
    - curl -fsS -m 10 --retry 5 https://hc-ping.com/your-uuid
  on_error:
    - curl -fsS -m 10 --retry 5 https://hc-ping.com/your-uuid/fail
```

## Advanced Configuration

### Backing Up Multiple Locations

```yaml
source_directories:
  - /mnt/source/appdata
  - /mnt/source/documents
  - /mnt/source/photos
  - /mnt/source/media

# Exclude patterns
exclude_patterns:
  - '*.tmp'
  - '*/cache/*'
  - '*/Cache/*'
  - '*/logs/*'
```

### Multiple Repositories with Different Schedules

Create multiple config files:

```bash
/mnt/user/appdata/borgmatic/.config/borgmatic/
├── local.yaml       # Daily local backups
└── remote.yaml      # Weekly remote backups
```

Each file can have its own schedule, repositories, and retention policies.

### Database Backups with Hooks

```yaml
hooks:
  before_backup:
    - docker exec mariadb mysqldump -u root -pPASSWORD --all-databases > /mnt/source/db-backup.sql
  after_backup:
    - rm /mnt/source/db-backup.sql
```

### Exclude Specific Directories

```yaml
exclude_patterns:
  - /mnt/source/appdata/plex/Library/Application Support/Plex Media Server/Cache
  - /mnt/source/appdata/*/cache
  - /mnt/source/appdata/*/logs
  - '*.log'
  - '*.tmp'
  - 'Thumbs.db'
  - '.DS_Store'
```

### Different Retention for Local vs Remote

Create separate config files:

**local.yaml**:
```yaml
repositories:
  - path: /mnt/borg-repository
retention:
  keep_daily: 7
  keep_weekly: 4
cron:
  - "0 2 * * *"  # Daily at 2 AM
```

**remote.yaml**:
```yaml
repositories:
  - path: ssh://user@server.com/backups/borg
retention:
  keep_weekly: 4
  keep_monthly: 12
  keep_yearly: 2
cron:
  - "0 3 * * 0"  # Weekly on Sunday at 3 AM
```

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
docker logs borgmatic

# Common issues:
# - Missing .env file
# - Incorrect volume paths
# - Permission issues

# Verify paths exist
ls -la /mnt/user/appdata/borgmatic
```

### Permission Denied Errors

```bash
# Fix permissions on appdata directory
chmod -R 755 /mnt/user/appdata/borgmatic
chown -R nobody:users /mnt/user/appdata/borgmatic

# SSH key permissions
chmod 700 /mnt/user/appdata/borgmatic/.ssh
chmod 600 /mnt/user/appdata/borgmatic/.ssh/id_ed25519
```

### SSH Connection Fails

```bash
# Test SSH from inside container
docker exec -it borgmatic bash
ssh -i /root/.ssh/id_ed25519 user@backup-server.com

# Check known_hosts
cat /root/.ssh/known_hosts

# Re-add host
ssh-keyscan backup-server.com >> /root/.ssh/known_hosts
```

### Passphrase Not Working

```bash
# Verify passphrase is set
docker exec borgmatic env | grep BORG_PASSPHRASE

# Test manually
docker exec -it borgmatic bash
export BORG_PASSPHRASE='your-passphrase'
borg list /mnt/borg-repository
```

### Repository Locked

```bash
# If backup crashed, repository may be locked
docker exec borgmatic borg break-lock /mnt/borg-repository

# Only use if you're sure no backup is running!
```

### High CPU Usage During Backups

```bash
# Use faster compression in config.yaml
compression: lz4

# Or disable compression entirely
compression: none
```

### Backups Not Running on Schedule

```bash
# Check cron is configured in config.yaml
docker exec borgmatic cat /root/.config/borgmatic/config.yaml | grep -A2 cron

# Check cron is running
docker exec borgmatic ps aux | grep cron

# View cron logs
docker logs borgmatic | grep CRON
```

## Security Best Practices

1. **Passphrase Management**
   - Use a strong, unique passphrase (20+ characters)
   - Store in password manager
   - Never commit `.env` to version control
   - Set file permissions: `chmod 600 .env`

2. **SSH Keys**
   - Use ed25519 keys (stronger than RSA)
   - Never share private keys
   - Use different keys for different servers
   - Set proper permissions (700 for .ssh/, 600 for private keys)

3. **Repository Keys**
   - Export and store offline immediately after initialization
   - Store in multiple secure locations
   - Test restoration with keys periodically

4. **Network Security**
   - Use SSH key authentication (never passwords)
   - Consider VPN for remote backups
   - Validate SSH host fingerprints

5. **Access Control**
   - Mount source directories as read-only (`:ro`)
   - Run container with minimal privileges
   - Use separate backup user on remote server

## Monitoring and Maintenance

### Regular Tasks

- **Daily**: Check logs for errors
- **Weekly**: Verify backups are running on schedule
- **Monthly**: Test restoration from backup
- **Quarterly**: Update Docker container
- **Yearly**: Review and update retention policies

### Update Container

```bash
# Pull latest image
docker-compose pull

# Recreate container
docker-compose up -d

# Or with docker command:
docker pull b3vis/borgmatic:latest
docker stop borgmatic
docker rm borgmatic
# Re-run docker run command with same parameters
```

### Monitor Disk Space

```bash
# Check repository size
docker exec borgmatic borg info /mnt/borg-repository

# Check local backup disk space
df -h /mnt/user/backups
```

## Example Configurations

### Minimal Setup (Local Backups Only)

```yaml
repositories:
  - path: /mnt/borg-repository

source_directories:
  - /mnt/source/appdata

retention:
  keep_daily: 7

cron:
  - "0 3 * * *"
```

### Local + Remote with Different Schedules

**config.yaml**:
```yaml
repositories:
  - path: /mnt/borg-repository
  - path: ssh://user@backup-server.com/backups/borg-unraid

source_directories:
  - /mnt/source/appdata
  - /mnt/source/documents

retention:
  keep_within: 14d
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 6

cron:
  - "0 2 * * *"  # Daily at 2 AM for local
  - "0 4 * * 0"  # Weekly on Sunday at 4 AM for remote
```

### Production Setup with All Features

```yaml
repositories:
  - path: /mnt/borg-repository
    label: local
  - path: ssh://backup@offsite.example.com:22/~/backups/unraid-borg
    label: offsite

source_directories:
  - /mnt/source/appdata
  - /mnt/source/important_docs

exclude_patterns:
  - /mnt/source/appdata/*/cache
  - /mnt/source/appdata/*/Cache
  - /mnt/source/appdata/*/logs
  - '*.tmp'
  - '*.log'

retention:
  keep_within: 14d
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 12
  keep_yearly: 2

consistency:
  checks:
    - name: repository
      frequency: 2 weeks
    - name: archives
      frequency: 1 month

hooks:
  before_backup:
    - echo "Starting backup on $(date)"
  after_backup:
    - echo "Backup completed on $(date)"
    - curl -fsS https://hc-ping.com/your-uuid
  on_error:
    - echo "Backup FAILED on $(date)" >&2
    - curl -fsS https://hc-ping.com/your-uuid/fail

cron:
  - "0 2 * * *"  # Daily at 2 AM
```

## Migration from Script-Based Setup

If you're migrating from a script-based setup (like the Fedora version):

1. **Export existing repository keys** (if you have existing repos)
   ```bash
   borg key export /path/to/old/repo ~/old-repo.key
   ```

2. **Import into borgmatic** (optional - or keep using existing repo)
   ```bash
   docker exec -it borgmatic bash
   borg key import /mnt/borg-repository /path/to/old-repo.key
   ```

3. **Update config.yaml** to point to existing repository

4. **Test with existing repository**
   ```bash
   docker exec borgmatic borgmatic list
   ```

5. **Disable old cron jobs** on Unraid
   ```bash
   crontab -e
   # Comment out old borg backup lines
   ```

6. **Remove old scripts** (after verifying new setup works)

## Comparison: Docker vs Script-Based

| Feature | Docker (borgmatic) | Script-based |
|---------|-------------------|--------------|
| Persistence | Automatic | Manual (go file or User Scripts) |
| Configuration | YAML | Shell scripts |
| Updates | `docker pull` | Manual reinstall |
| Scheduling | Built-in cron | Unraid cron or User Scripts |
| Monitoring | Integrated hooks | Manual implementation |
| Complexity | Medium | High |
| Unraid Integration | Excellent | Good |
| Resource Usage | Slightly higher | Lower |

## Resources

- [Borgmatic Documentation](https://torsion.org/borgmatic/)
- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [b3vis/borgmatic Docker Hub](https://hub.docker.com/r/b3vis/borgmatic)
- [Cron Schedule Generator](https://crontab.guru/)
- [Unraid Docker Guide](https://wiki.unraid.net/Docker_Management)

## Support

- **Unraid Forums**: [Backup Discussions](https://forums.unraid.net/)
- **Borgmatic Issues**: [GitHub Issues](https://github.com/witten/borgmatic/issues)
- **BorgBackup Community**: [Mailing List](https://mail.python.org/mailman/listinfo/borgbackup)

## License

These configuration files are provided as-is for use with Unraid systems. BorgBackup and borgmatic are licensed under their respective licenses.
