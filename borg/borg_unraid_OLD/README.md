# Borg Backup Automated Setup for Unraid

This script automates the installation and configuration of BorgBackup with scheduled backups to local and/or remote (SSH) destinations on Unraid servers.

## What It Does

The setup script will:

1. Install or verify BorgBackup installation on your Unraid server
2. Create secure encrypted backup repositories (local and/or remote)
3. Generate and store encryption keys safely (persistent on USB flash)
4. Create backup scripts for automated backups
5. Set up cron jobs to run backups on your chosen schedule
6. Optionally create User Scripts for GUI management
7. Display all credentials (passphrase and keys) for secure storage

## Features

- **Dual backup destinations**: Configure both local and remote SSH backups independently
- **Flexible scheduling**: Set different schedules for local vs remote backups using cron
- **Encrypted backups**: Uses repokey encryption with a passphrase
- **Automated pruning**: Keeps backups based on retention policy
- **Credential backup**: Displays passphrase and repository keys for safekeeping
- **Unraid-aware**: Keys stored on persistent USB flash (/boot/config/)
- **User Scripts integration**: Optional GUI management via User Scripts plugin
- **Re-run safety**: Detects existing installations and protects against accidental overwrites

## Important: Unraid Persistence

Unraid boots from RAM, so most files are temporary and lost on reboot. This setup handles persistence as follows:

**Persistent (survives reboots):**
- Repository keys in `/boot/config/`
- Cron jobs (automatically persisted)
- User Scripts (if plugin installed)

**Temporary (lost on reboot):**
- `/etc/backups/` directory and contents
- `/root/borg-*-repo.key` files

**Options for persistence:**
1. Add initialization to your `go` file (see section below)
2. Re-run the setup script after each reboot
3. Use User Scripts plugin to run backups (recommended)

## Prerequisites

- Root access to your Unraid server
- BorgBackup installed via Nerd Tools or Docker
- For remote backups:
  - SSH access to remote server
  - BorgBackup installed on remote server
  - SSH key authentication configured (passwordless)

## Installation

### Step 1: Install BorgBackup

Choose one of these methods:

**Method A: Nerd Tools (Recommended)**
1. Install "Nerd Tools" plugin from Community Applications
2. Open Nerd Tools settings
3. Enable and install "borgbackup"

**Method B: Docker Container**
```bash
docker run -it --rm -v /mnt/user:/mnt/user \
  nold360/borgbackup borg --version
```

**Method C: Manual Installation**
Download and install borgbackup binary manually.

### Step 2: Download This Setup

Upload these files to your Unraid server, for example to `/boot/config/borg-setup/`:
- `borg-setup.sh`
- `borg-setup.conf`
- `README.md` (this file)

### Step 3: Edit the Configuration

Edit `borg-setup.conf` and configure:

```bash
# Set the directories to back up (space-separated list)
# Single source:
BACKUP_SOURCES="/mnt/user/appdata"

# Multiple sources:
BACKUP_SOURCES="/mnt/user/appdata /mnt/user/documents /mnt/user/photos"

# Set a strong passphrase (REQUIRED)
BORG_PASSPHRASE=your-strong-passphrase-here

# Enable/disable local backups
ENABLE_LOCAL=yes
LOCAL_REPO=/mnt/user/backups/borg-local
# or: /mnt/disk2/backups/borg-local   # Specific disk
# or: /mnt/disks/USB_Backup/borg      # Unassigned device

# Cron schedule (minute hour day month weekday)
LOCAL_CRON_SCHEDULE="0 2 1,15 * *"   # 2 AM on 1st and 15th

# Enable/disable remote backups
ENABLE_REMOTE=yes
REMOTE_REPO=user@backup-server.com:/backups/borg-remote
REMOTE_CRON_SCHEDULE="0 4 1 * *"     # 4 AM on 1st of month
```

### Step 4: For Remote Backups - Set Up SSH Keys

If using remote backups, set up SSH key authentication as root:

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -f /boot/config/ssh/id_ed25519

# Copy key to remote server
ssh-copy-id -i /boot/config/ssh/id_ed25519 user@backup-server.com

# Test connection
ssh -i /boot/config/ssh/id_ed25519 user@backup-server.com "borg --version"
```

**Note**: Store SSH keys in `/boot/config/ssh/` to persist across reboots.

### Step 5: Run the Setup Script

```bash
cd /boot/config/borg-setup/
bash borg-setup.sh
```

The script will:
- Check for existing installations and warn if files will be overwritten
- Show you a summary of what will be configured
- Ask for confirmation before proceeding
- Install/verify BorgBackup
- Initialize repositories (skips if they already exist)
- Create backup scripts
- Set up cron jobs
- Create User Scripts (if plugin installed)
- Display your credentials

### Step 6: Save Your Credentials

**CRITICAL**: When the script completes, it will display:
- Your passphrase
- Your repository key(s) (full contents)

**You MUST save both** to a secure location (password manager, encrypted USB, etc). You need BOTH to recover backups if your system fails.

The keys are also saved to:
- `/boot/config/borg-local-repo.key` (persistent)
- `/boot/config/borg-remote-repo.key` (persistent)

### Step 7: Test Your Backup

Before relying on the automated schedule, test the backup manually:

```bash
# Test local backup
/etc/backups/run-local.sh

# Test remote backup (if enabled)
/etc/backups/run-remote.sh

# Check the logs
tail -f /var/log/borg-local.log
tail -f /var/log/borg-remote.log
```

## Making Backups Persistent Across Reboots

Since Unraid boots from RAM, you need to make the backup configuration persistent. Choose one of these options:

### Option A: Add to Go File (Recommended for Cron)

Edit `/boot/config/go` and add before the final line:

```bash
# Borg Backup Setup
mkdir -p /etc/backups
cp /boot/config/borg-passphrase /etc/backups/passphrase
cp /boot/config/borg-run-local.sh /etc/backups/run-local.sh
cp /boot/config/borg-run-remote.sh /etc/backups/run-remote.sh
chmod 600 /etc/backups/passphrase
chmod +x /etc/backups/run-*.sh
```

Then save the required files to `/boot/config/`:

```bash
cp /etc/backups/passphrase /boot/config/borg-passphrase
cp /etc/backups/run-local.sh /boot/config/borg-run-local.sh
cp /etc/backups/run-remote.sh /boot/config/borg-run-remote.sh
```

### Option B: Use User Scripts Plugin (Recommended for GUI)

If you installed the User Scripts plugin, the backup scripts are already set up in the GUI:
1. Go to Settings > User Scripts
2. You'll see "borg_backup_local" and/or "borg_backup_remote"
3. Set schedules directly in the GUI
4. The User Scripts plugin handles persistence automatically

**Note**: If using User Scripts for scheduling, you can remove the cron entries to avoid duplicate backups.

### Option C: Re-run Setup After Reboot

Simply re-run the setup script after each reboot. It will detect existing repositories and skip initialization.

## Configuration Options

### Backup Sources
```bash
# Single directory
BACKUP_SOURCES="/mnt/user/appdata"

# Multiple directories (space-separated)
BACKUP_SOURCES="/mnt/user/appdata /mnt/user/documents /mnt/user/photos"
```
The directories you want to back up. BorgBackup will include all specified sources in a single backup archive. Common Unraid paths:
- `/mnt/user/appdata` - Docker containers
- `/mnt/user/shares` - All user shares
- `/mnt/disk1` - Specific disk
- `/mnt/cache` - Cache drive

**Note**: All sources are backed up into a single archive. They will all have the same retention policy and schedule.

### Passphrase
```bash
BORG_PASSPHRASE=changeme
```
Encryption passphrase. Make it strong - you'll need it to access backups.

### Compression
```bash
COMPRESSION=lz4           # Fast, low CPU usage (recommended for Unraid)
COMPRESSION=zstd,3        # Better compression ratio
COMPRESSION=lzma,6        # Maximum compression (slow, high CPU)
```

### Retention Policy
```bash
KEEP_WITHIN=14d           # Keep all backups from last 14 days
KEEP_MONTHLY=4            # Keep 4 monthly backups
```

### Cron Schedule Format
```bash
# minute hour day month weekday
"0 2 1,15 * *"   # 2 AM on 1st and 15th of each month
"0 2 1 * *"      # 2 AM on 1st of each month only
"0 3 * * 0"      # 3 AM every Sunday
"0 2 */7 * *"    # 2 AM every 7 days
```

**Note**: Stagger local and remote backup times (e.g., local at 02:00, remote at 04:00) to avoid running them simultaneously.

## File Locations After Setup

### Persistent Files (survive reboot)
- `/boot/config/borg-local-repo.key` - Local repository key
- `/boot/config/borg-remote-repo.key` - Remote repository key
- Cron jobs (managed by Unraid)
- User Scripts (if plugin installed)

### Temporary Files (lost on reboot unless made persistent)
- `/etc/backups/passphrase` - Encrypted passphrase file (chmod 600)
- `/etc/backups/run-local.sh` - Local backup script
- `/etc/backups/run-remote.sh` - Remote backup script
- `/root/borg-local-repo.key` - Local repository key (duplicate)
- `/root/borg-remote-repo.key` - Remote repository key (duplicate)

### Logs
- `/var/log/borg-local.log` - Local backup log
- `/var/log/borg-remote.log` - Remote backup log

## Managing Backups

### View Cron Schedule
```bash
crontab -l
```

### Run a Backup Manually
```bash
# Local backup
/etc/backups/run-local.sh

# Remote backup
/etc/backups/run-remote.sh

# Or via User Scripts GUI
# Settings > User Scripts > Click "Run Script"
```

### View Backup Logs
```bash
# View entire log
cat /var/log/borg-local.log

# Follow log in real-time
tail -f /var/log/borg-local.log

# Last 50 lines
tail -n 50 /var/log/borg-remote.log
```

### Disable/Enable Backups
```bash
# Edit crontab
crontab -e
# Comment out the borg-backup lines with #

# Or remove entirely
crontab -l | grep -v "borg-backup" | crontab -

# Or disable in User Scripts GUI
# Settings > User Scripts > Disable schedule
```

## Restoring from Backup

### List Available Backups
```bash
export BORG_PASSCOMMAND="cat /etc/backups/passphrase"
borg list /mnt/user/backups/borg-local
# or for remote:
borg list user@backup-server.com:/backups/borg-remote
```

### Extract Files
```bash
export BORG_PASSCOMMAND="cat /etc/backups/passphrase"

# Extract entire backup
borg extract /mnt/user/backups/borg-local::2024-01-15-Tower

# Extract specific file
borg extract /mnt/user/backups/borg-local::2024-01-15-Tower mnt/user/appdata/plex
```

### Restore on a Different System

If your Unraid server failed, you need:
1. The repository (local backup drive or SSH access to remote)
2. The passphrase (from your password manager)
3. The repository key file (borg-local-repo.key or borg-remote-repo.key)

```bash
# Install borg on new system
# (Install BorgBackup via your distro's package manager)

# Import the key
export BORG_PASSPHRASE='your-passphrase'
borg key import /path/to/repo /path/to/borg-repo.key

# List backups
borg list /path/to/repo

# Extract
borg extract /path/to/repo::backup-name
```

## Troubleshooting

### Check if Borg is Running
```bash
ps aux | grep borg
```

### View Recent Backup Output
```bash
tail -n 100 /var/log/borg-local.log
```

### Test SSH Connection (for remote backups)
```bash
ssh user@backup-server.com
```

### Verify Repository
```bash
export BORG_PASSCOMMAND="cat /etc/backups/passphrase"
borg info /mnt/user/backups/borg-local
```

### Manual Backup Test
```bash
# Run the script manually to see any errors
bash -x /etc/backups/run-local.sh
```

### Passphrase Mismatch Error
If you see errors like "passphrase supplied in BORG_PASSPHRASE is incorrect":
1. Check the current passphrase: `cat /etc/backups/passphrase`
2. This passphrase was set when the repository was created
3. Update `borg-setup.conf` to match the original passphrase
4. Or, if you know the original passphrase, manually update `/etc/backups/passphrase`

### Backup Scripts Missing After Reboot
If `/etc/backups/` is empty after reboot, the scripts weren't made persistent. See "Making Backups Persistent Across Reboots" section.

### BorgBackup Not Found
```bash
# Check if installed
which borg

# Install via Nerd Tools or Docker
# See Installation section above
```

## Security Notes

- The passphrase is stored in `/etc/backups/passphrase` with 600 permissions (root only)
- Always keep offline copies of your passphrase and repository keys
- Repository keys are stored on USB flash in `/boot/config/` (survives reboots)
- Consider storing keys in multiple secure locations
- Remote backups go over SSH - ensure your SSH keys are secure
- Repository keys are different from SSH keys - you need BOTH the passphrase AND the repository key to decrypt backups

## Example Use Cases

### Backup Docker Appdata Locally Every 2 Weeks
```bash
BACKUP_SOURCES="/mnt/user/appdata"
ENABLE_LOCAL=yes
LOCAL_REPO=/mnt/user/backups/borg-local
LOCAL_CRON_SCHEDULE="0 2 1,15 * *"

ENABLE_REMOTE=no
```

### Backup Multiple Directories to Remote Server Monthly
```bash
BACKUP_SOURCES="/mnt/user/appdata /mnt/user/documents /mnt/user/photos"
ENABLE_LOCAL=no

ENABLE_REMOTE=yes
REMOTE_REPO=user@offsite.com:/backups/unraid-borg
REMOTE_CRON_SCHEDULE="0 4 1 * *"
```

### Both Local and Remote (Recommended)
```bash
BACKUP_SOURCES="/mnt/user/appdata"

ENABLE_LOCAL=yes
LOCAL_REPO=/mnt/disk2/backups/borg-local
LOCAL_CRON_SCHEDULE="0 2 1,15 * *"   # 1st and 15th at 2 AM

ENABLE_REMOTE=yes
REMOTE_REPO=user@offsite.com:/backups/borg
REMOTE_CRON_SCHEDULE="0 4 1 * *"     # 1st at 4 AM (staggered)
```

### Backup to Unassigned Device
```bash
BACKUP_SOURCES="/mnt/user/appdata"
ENABLE_LOCAL=yes
LOCAL_REPO=/mnt/disks/USB_Backup/borg-repo
LOCAL_CRON_SCHEDULE="0 3 * * 0"   # 3 AM every Sunday

ENABLE_REMOTE=no
```

### Backup Multiple Sources with Different Priorities
```bash
# Backup critical data: appdata, important docs, family photos
BACKUP_SOURCES="/mnt/user/appdata /mnt/user/important_docs /mnt/user/family_photos"

ENABLE_LOCAL=yes
LOCAL_REPO=/mnt/disk2/backups/borg-local
LOCAL_CRON_SCHEDULE="0 2 */3 * *"    # Every 3 days at 2 AM

ENABLE_REMOTE=yes
REMOTE_REPO=user@offsite.com:/backups/critical
REMOTE_CRON_SCHEDULE="0 4 */7 * *"   # Every 7 days at 4 AM
```

## Unraid-Specific Tips

### Array Management
- If backing up to the array, backups may spin up all disks
- Consider using a dedicated backup disk or unassigned device
- Use `/mnt/diskX` to target a specific disk instead of `/mnt/user`

### Docker Containers
- Stop containers before backup for consistency:
  ```bash
  docker stop container_name
  /etc/backups/run-local.sh
  docker start container_name
  ```
- Or add to the backup script before the `borg create` command

### Parity Checks
- Schedule backups to avoid running during parity checks
- Check your parity schedule and adjust backup times accordingly

### Performance
- Use `lz4` compression for fastest backups
- Consider running backups during low-usage hours
- Monitor CPU and disk usage during first backup

### User Scripts Integration
- User Scripts provides email notifications on completion/failure
- Logs are visible in the GUI
- Easy to run manual backups with one click

## Additional Resources

- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [BorgBackup Quick Start](https://borgbackup.readthedocs.io/en/stable/quickstart.html)
- [Unraid Forums - Backup Discussions](https://forums.unraid.net/)
- [Cron Schedule Expression](https://crontab.guru/)

## Differences from Fedora Version

This Unraid version differs from the Fedora version in these ways:

1. **No systemd** - Uses cron instead of systemd timers
2. **Persistence handling** - Keys stored in `/boot/config/` to survive reboots
3. **User Scripts support** - Optional GUI management via User Scripts plugin
4. **Package installation** - Supports Nerd Tools instead of dnf/apt
5. **Unraid paths** - Examples use `/mnt/user/`, `/mnt/disk#/`, etc.
6. **Additional warnings** - Explains Unraid's RAM-based boot and persistence requirements
