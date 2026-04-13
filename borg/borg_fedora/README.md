# Borg Backup Automated Setup

This script automates the installation and configuration of BorgBackup with scheduled backups to local and/or remote (SSH) destinations.

## What It Does

The setup script will:

1. Install BorgBackup on your system (via dnf or apt-get)
2. Create secure encrypted backup repositories (local and/or remote)
3. Generate and store encryption keys safely
4. Create backup scripts for automated backups
5. Set up systemd timers to run backups on your chosen schedule
6. Display all credentials (passphrase and keys) for secure storage

## Features

- **Dual backup destinations**: Configure both local and remote SSH backups independently
- **Flexible scheduling**: Set different schedules for local vs remote backups
- **Encrypted backups**: Uses repokey encryption with a passphrase
- **Automated pruning**: Keeps backups based on retention policy
- **Credential backup**: Displays passphrase and repository keys for safekeeping
- **Re-run safety**: Detects existing installations and protects against accidental overwrites
- **Automatic backups**: Creates timestamped backups of existing config files before overwriting

## Prerequisites

- Root access (script must run as root)
- For remote backups:
  - SSH access to remote server
  - BorgBackup installed on remote server
  - SSH key authentication configured (passwordless)

## Quick Start

### 1. Edit the Configuration

Open `borg-setup.conf` and configure:

```bash
# Set the directories to back up (space-separated list)
# Single source:
BACKUP_SOURCES="/disk1"

# Multiple sources:
BACKUP_SOURCES="/disk1 /home/user/documents /var/www"

# Set a strong passphrase (REQUIRED)
BORG_PASSPHRASE=your-strong-passphrase-here

# Enable/disable local backups
ENABLE_LOCAL=yes
LOCAL_REPO=/disk2/backup/borg-local
LOCAL_SCHEDULE_DAYS=1,15   # 1st and 15th of month
LOCAL_SCHEDULE_TIME=02:00:00

# Enable/disable remote backups
ENABLE_REMOTE=yes
REMOTE_REPO=user@backup-server.com:/backups/borg-remote
REMOTE_SCHEDULE_DAYS=1     # 1st of month
REMOTE_SCHEDULE_TIME=04:00:00
```

### 2. For Remote Backups: Set Up SSH Keys

If using remote backups, set up SSH key authentication as root:

```bash
# Generate SSH key (if you don't have one)
sudo ssh-keygen -t ed25519

# Copy key to remote server
sudo ssh-copy-id user@backup-server.com

# Test connection
sudo ssh user@backup-server.com "borg --version"
```

### 3. Run the Setup Script

```bash
sudo bash borg-setup.sh
```

The script will:
- Check for existing installations and warn if files will be overwritten
- Show you a summary of what will be configured
- Ask for confirmation before proceeding
- Install BorgBackup
- Initialize repositories (skips if they already exist)
- Create backup scripts and timers (backs up existing files first)
- Display your credentials

### 4. Save Your Credentials

**CRITICAL**: When the script completes, it will display:
- Your passphrase
- Your repository key(s) (both location and full contents)

**You MUST save both** to a secure location (password manager, encrypted USB, etc). You need BOTH to recover backups if your system fails.

### 5. Test Your Backup

Before relying on the automated schedule, test the backup manually:

```bash
# Test local backup
sudo /etc/backups/run-local.sh

# Test remote backup (if enabled)
sudo /etc/backups/run-remote.sh

# Check the logs
sudo journalctl -u borg-backup-local.service -n 50
```

## Configuration Options

### Backup Sources
```bash
# Single directory
BACKUP_SOURCES="/disk1"

# Multiple directories (space-separated)
BACKUP_SOURCES="/disk1 /home/user/documents /var/www"
```
The directories you want to back up. BorgBackup will include all specified sources in a single backup archive.

**Note**: All sources are backed up into a single archive. They will all have the same retention policy and schedule.

### Passphrase
```bash
BORG_PASSPHRASE=changeme
```
Encryption passphrase. Make it strong - you'll need it to access backups.

### Compression
```bash
COMPRESSION=lz4           # Fast, low CPU usage
COMPRESSION=zstd,3        # Better compression ratio
COMPRESSION=lzma,6        # Maximum compression
```

### Retention Policy
```bash
KEEP_WITHIN=14d           # Keep all backups from last 14 days
KEEP_MONTHLY=4            # Keep 4 monthly backups
```

### Schedule Format
```bash
SCHEDULE_DAYS=1,15        # 1st and 15th of each month
SCHEDULE_DAYS=1           # 1st of each month only
SCHEDULE_DAYS=*/7         # Every 7 days
SCHEDULE_TIME=02:00:00    # 2 AM (24-hour format)
SCHEDULE_TIME=04:00:00    # 4 AM (stagger remote backups to avoid conflicts)
```

**Note**: If running both local and remote backups, stagger the times (e.g., local at 02:00, remote at 04:00) to avoid running them simultaneously.

## File Locations After Setup

### Configuration and Scripts
- `/etc/backups/passphrase` - Encrypted passphrase file (chmod 600)
- `/etc/backups/run-local.sh` - Local backup script
- `/etc/backups/run-remote.sh` - Remote backup script

### Repository Keys
- `/root/borg-local-repo.key` - Local repository key
- `/root/borg-remote-repo.key` - Remote repository key

### Systemd Services
- `/etc/systemd/system/borg-backup-local.service` - Local backup service
- `/etc/systemd/system/borg-backup-local.timer` - Local backup timer
- `/etc/systemd/system/borg-backup-remote.service` - Remote backup service
- `/etc/systemd/system/borg-backup-remote.timer` - Remote backup timer

## Managing Backups

### Check Next Scheduled Backups
```bash
systemctl list-timers
```

### Run a Backup Manually
```bash
# Local backup
sudo /etc/backups/run-local.sh

# Remote backup
sudo /etc/backups/run-remote.sh
```

### View Backup Status
```bash
# Check local timer status
systemctl status borg-backup-local.timer

# Check remote timer status
systemctl status borg-backup-remote.timer

# View logs
journalctl -u borg-backup-local.service
journalctl -u borg-backup-remote.service
```

### Disable/Enable Backups
```bash
# Disable local backups
sudo systemctl stop borg-backup-local.timer
sudo systemctl disable borg-backup-local.timer

# Re-enable
sudo systemctl enable --now borg-backup-local.timer
```

## Restoring from Backup

### List Available Backups
```bash
export BORG_PASSCOMMAND="cat /etc/backups/passphrase"
borg list /disk2/backup/borg-local
# or for remote:
borg list user@backup-server.com:/backups/borg-remote
```

### Extract Files
```bash
export BORG_PASSCOMMAND="cat /etc/backups/passphrase"

# Extract entire backup
borg extract /disk2/backup/borg-local::2024-01-15-hostname

# Extract specific file
borg extract /disk2/backup/borg-local::2024-01-15-hostname path/to/file
```

### Restore on a Different System

If your original system failed, you need:
1. The repository (local backup drive or SSH access to remote)
2. The passphrase (from your password manager)
3. The repository key file (borg-local-repo.key or borg-remote-repo.key)

```bash
# Install borg
sudo apt-get install borgbackup

# Import the key
export BORG_PASSPHRASE='your-passphrase'
borg key import /path/to/repo /path/to/borg-repo.key

# List backups
borg list /path/to/repo

# Extract
borg extract /path/to/repo::backup-name
```

## Re-running the Setup Script

If you need to re-run the setup script (e.g., to add a remote backup after initial setup), the script will:

1. **Detect existing installation** and warn you about what will be overwritten
2. **Check passphrase consistency** - warns if your config passphrase differs from the existing one (which would break backups)
3. **Create timestamped backups** of existing files before overwriting:
   - `/etc/backups/run-local.sh.bak.20240115-143022`
   - `/etc/systemd/system/borg-backup-local.service.bak.20240115-143022`
4. **Skip repository initialization** if repositories already exist (preserves your backups)

**Recommendation**: Instead of re-running the entire script, manually edit the relevant files:
- To change schedule: Edit `/etc/systemd/system/borg-backup-local.timer` and run `sudo systemctl daemon-reload`
- To change backup settings: Edit `/etc/backups/run-local.sh`
- To change retention: Edit `/etc/backups/run-local.sh` and modify the `borg prune` parameters

## Troubleshooting

### Check if Borg is Running
```bash
ps aux | grep borg
```

### View Recent Backup Output
```bash
journalctl -u borg-backup-local.service -n 50

# Follow logs in real-time
journalctl -u borg-backup-local.service -f
```

### Test SSH Connection (for remote backups)
```bash
sudo ssh user@backup-server.com
```

### Verify Repository
```bash
export BORG_PASSCOMMAND="cat /etc/backups/passphrase"
borg info /disk2/backup/borg-local
```

### Manual Backup Test
```bash
# Run the script manually to see any errors
sudo bash -x /etc/backups/run-local.sh
```

### Passphrase Mismatch Error
If you see errors like "passphrase supplied in BORG_PASSPHRASE is incorrect":
1. Check the current passphrase: `sudo cat /etc/backups/passphrase`
2. This passphrase was set when the repository was created
3. Update `borg-setup.conf` to match the original passphrase
4. Or, if you know the original passphrase, manually update `/etc/backups/passphrase`

## Security Notes

- The passphrase is stored in `/etc/backups/passphrase` with 600 permissions (root only)
- Always keep offline copies of your passphrase and repository keys
- Consider storing keys in multiple secure locations
- Remote backups go over SSH - ensure your SSH keys are secure
- Repository keys are different from SSH keys - you need BOTH the passphrase AND the repository key to decrypt backups

## Example Use Cases

### Local Backup Only (Every 2 Weeks)
```bash
BACKUP_SOURCES="/disk1"
ENABLE_LOCAL=yes
LOCAL_SCHEDULE_DAYS=1,15

ENABLE_REMOTE=no
```

### Remote Backup Only (Monthly) with Multiple Sources
```bash
BACKUP_SOURCES="/disk1 /home/user/documents /var/www"
ENABLE_LOCAL=no

ENABLE_REMOTE=yes
REMOTE_SCHEDULE_DAYS=1
```

### Both Local and Remote (Local Every 2 Weeks, Remote Monthly)
```bash
BACKUP_SOURCES="/disk1"
ENABLE_LOCAL=yes
LOCAL_SCHEDULE_DAYS=1,15

ENABLE_REMOTE=yes
REMOTE_SCHEDULE_DAYS=1
```

### Multiple Critical Directories with Frequent Backups
```bash
BACKUP_SOURCES="/home/user/projects /var/lib/postgresql /etc"
ENABLE_LOCAL=yes
LOCAL_SCHEDULE_DAYS=*/1  # Daily
LOCAL_SCHEDULE_TIME=03:00:00

ENABLE_REMOTE=yes
REMOTE_SCHEDULE_DAYS=1,15  # Twice monthly
REMOTE_SCHEDULE_TIME=04:00:00
```

## Additional Resources

- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [BorgBackup Quick Start](https://borgbackup.readthedocs.io/en/stable/quickstart.html)
- [Systemd Timer Documentation](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)
