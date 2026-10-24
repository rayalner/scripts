#!/bin/bash
# ============================================================
# Borg Backup Setup Script for Unraid
# Run as root: bash borg-setup.sh
# ============================================================

set -e

# ---- Load config ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/borg-setup.conf"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: Config file not found at $CONFIG"
    echo "Make sure borg-setup.conf is in the same directory as this script."
    exit 1
fi

source "$CONFIG"

# ---- Sanity checks ----
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root: bash borg-setup.sh"
    exit 1
fi

if [ "$BORG_PASSPHRASE" = "changeme" ]; then
    echo "ERROR: You have not set a passphrase in borg-setup.conf"
    exit 1
fi

# Validate all backup sources exist
for source in $BACKUP_SOURCES; do
    if [ ! -d "$source" ]; then
        echo "ERROR: Backup source $source does not exist"
        exit 1
    fi
done

if [ "$ENABLE_LOCAL" != "yes" ] && [ "$ENABLE_REMOTE" != "yes" ]; then
    echo "ERROR: At least one of ENABLE_LOCAL or ENABLE_REMOTE must be set to 'yes'"
    exit 1
fi

# ---- Check for existing installation ----
EXISTING_INSTALL=no
WARNINGS=""

if [ -f /boot/config/plugins/user.scripts/scripts/borg_backup_local/script ] || \
   [ -f /boot/config/plugins/user.scripts/scripts/borg_backup_remote/script ]; then
    EXISTING_INSTALL=yes
    WARNINGS="${WARNINGS}\n  - User Scripts in /boot/config/plugins/user.scripts/scripts/ will be overwritten"
fi

if [ -f /etc/backups/passphrase ]; then
    EXISTING_INSTALL=yes
    WARNINGS="${WARNINGS}\n  - /etc/backups/passphrase will be overwritten"

    # Check if passphrase has changed
    CURRENT_PASS=$(cat /etc/backups/passphrase)
    if [ "$CURRENT_PASS" != "$BORG_PASSPHRASE" ]; then
        WARNINGS="${WARNINGS}\n  - WARNING: Passphrase in config differs from existing passphrase!"
        WARNINGS="${WARNINGS}\n    This will cause backup failures. Repos use the old passphrase."
    fi
fi

if [ -f /etc/backups/run-local.sh ] || [ -f /etc/backups/run-remote.sh ]; then
    EXISTING_INSTALL=yes
    WARNINGS="${WARNINGS}\n  - Backup scripts in /etc/backups/ will be overwritten"
fi

# Check for cron entries
if crontab -l 2>/dev/null | grep -q "borg-backup"; then
    EXISTING_INSTALL=yes
    WARNINGS="${WARNINGS}\n  - Existing borg-backup cron entries will be replaced"
fi

if [ "$EXISTING_INSTALL" = "yes" ]; then
    echo ""
    echo "============================================================"
    echo " WARNING: Existing Installation Detected"
    echo "============================================================"
    echo -e "$WARNINGS"
    echo ""
    echo " It's recommended to manually edit existing files rather"
    echo " than re-running this setup script."
    echo ""
    read -rp "Continue anyway? [y/N] " overwrite_confirm
    if [[ ! "$overwrite_confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "============================================================"
echo " Borg Backup Setup for Unraid"
echo "============================================================"
echo " Sources:     $BACKUP_SOURCES"
echo " Compression: $COMPRESSION"
echo ""
if [ "$ENABLE_LOCAL" = "yes" ]; then
    echo " Local Backup:  ENABLED"
    echo "   Repository:  $LOCAL_REPO"
    echo "   Cron:        $LOCAL_CRON_SCHEDULE"
else
    echo " Local Backup:  DISABLED"
fi
echo ""
if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo " Remote Backup: ENABLED"
    echo "   Repository:  $REMOTE_REPO"
    echo "   Cron:        $REMOTE_CRON_SCHEDULE"
else
    echo " Remote Backup: DISABLED"
fi
echo "============================================================"
read -rp "Proceed? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ---- Install Borg ----
echo ""
echo "[1/6] Installing borgbackup..."

# Check if borg is already installed
if command -v borg &>/dev/null; then
    echo "      BorgBackup is already installed ($(borg --version))"
else
    # Try installing via Nerd Tools or slackpkg
    if [ -f /usr/local/emhttp/plugins/NerdTools/scripts/install ]; then
        echo "      Installing via Nerd Tools..."
        /usr/local/emhttp/plugins/NerdTools/scripts/install borgbackup
    else
        echo ""
        echo "================================================================"
        echo " MANUAL INSTALLATION REQUIRED"
        echo "================================================================"
        echo " Please install BorgBackup manually using one of these methods:"
        echo ""
        echo " 1. Install 'Nerd Tools' plugin from Community Applications"
        echo "    Then install 'borgbackup' from Nerd Tools"
        echo ""
        echo " 2. OR use a Docker container:"
        echo "    docker run -it --rm -v /mnt/user:/mnt/user \\"
        echo "      nold360/borgbackup borg --version"
        echo ""
        echo " 3. OR manually download and install borgbackup"
        echo "================================================================"
        echo ""
        read -rp "Have you installed BorgBackup? Continue anyway? [y/N] " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            echo "Aborted. Install BorgBackup and re-run this script."
            exit 1
        fi
    fi
fi
echo "      Done."

# ---- Create directories ----
echo ""
echo "[2/6] Creating directories..."
mkdir -p /etc/backups

if [ "$ENABLE_LOCAL" = "yes" ]; then
    # Only create local directory if it's a local path (not SSH)
    if [[ ! "$LOCAL_REPO" =~ ^[a-zA-Z0-9_-]+@.*: ]] && [[ ! "$LOCAL_REPO" =~ ^ssh:// ]]; then
        mkdir -p "$(dirname "$LOCAL_REPO")"
    fi
fi
echo "      Done."

# ---- Store passphrase ----
echo ""
echo "[3/6] Storing passphrase securely..."

if [ -f /etc/backups/passphrase ]; then
    CURRENT_PASS=$(cat /etc/backups/passphrase)
    if [ "$CURRENT_PASS" = "$BORG_PASSPHRASE" ]; then
        echo "      Passphrase file already exists with same value, skipping."
    else
        echo "      WARNING: Overwriting existing passphrase (as confirmed earlier)."
        echo "$BORG_PASSPHRASE" > /etc/backups/passphrase
        chmod 600 /etc/backups/passphrase
    fi
else
    echo "$BORG_PASSPHRASE" > /etc/backups/passphrase
    chmod 600 /etc/backups/passphrase
    echo "      Done."
fi

# ---- Initialize Borg repos ----
echo ""
echo "[4/6] Initializing Borg repositories..."

init_repo() {
    local repo=$1
    local name=$2

    echo ""
    echo "      Initializing $name repository at $repo..."

    # Check if repo exists (works for both local and SSH)
    if BORG_PASSCOMMAND="cat /etc/backups/passphrase" borg info "$repo" &>/dev/null; then
        echo "      Repository already exists, skipping init."
    else
        BORG_PASSCOMMAND="cat /etc/backups/passphrase" \
            borg init --encryption=repokey "$repo"
        echo "      Done."
    fi

    # Always export key (whether new or existing repo)
    echo "      Exporting repo key to /boot/config/borg-${name}-repo.key (keep this safe!)..."
    BORG_PASSCOMMAND="cat /etc/backups/passphrase" \
        borg key export "$repo" /boot/config/borg-${name}-repo.key 2>/dev/null || true
    # Also keep a copy in /root for immediate access
    BORG_PASSCOMMAND="cat /etc/backups/passphrase" \
        borg key export "$repo" /root/borg-${name}-repo.key 2>/dev/null || true
    echo "      Done."
}

if [ "$ENABLE_LOCAL" = "yes" ]; then
    init_repo "$LOCAL_REPO" "local"
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    init_repo "$REMOTE_REPO" "remote"
fi

# ---- Create backup scripts ----
echo ""
echo "[5/6] Creating backup scripts..."

create_backup_script() {
    local repo=$1
    local name=$2
    local script_path="/etc/backups/run-${name}.sh"

    # Backup existing script if it exists
    if [ -f "$script_path" ]; then
        cp "$script_path" "${script_path}.bak.$(date +%Y%m%d-%H%M%S)"
        echo "      Backed up existing ${script_path} to .bak file"
    fi

    cat > "$script_path" << 'EOF'
#!/bin/bash -ue

export BORG_PASSCOMMAND="cat /etc/backups/passphrase"
export BORG_RELOCATED_REPO_ACCESS_IS_OK=no
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=no

TARGET=REPO_PLACEHOLDER
DATE=$(date --iso-8601)-$(hostname)

echo "Starting Borg NAME_PLACEHOLDER backup: $DATE"
borg --version

borg create \
  --stats \
  --one-file-system \
  --compression COMPRESSION_PLACEHOLDER \
  --checkpoint-interval 86400 \
  $TARGET::$DATE \
  SOURCE_PLACEHOLDER

borg prune \
  --keep-within KEEP_WITHIN_PLACEHOLDER \
  --keep-monthly KEEP_MONTHLY_PLACEHOLDER \
  $TARGET

sync
echo "Backup complete."
EOF

    # Replace placeholders
    sed -i "s|REPO_PLACEHOLDER|$repo|g" "$script_path"
    sed -i "s|NAME_PLACEHOLDER|$name|g" "$script_path"
    sed -i "s|COMPRESSION_PLACEHOLDER|$COMPRESSION|g" "$script_path"
    sed -i "s|SOURCE_PLACEHOLDER|$BACKUP_SOURCES|g" "$script_path"
    sed -i "s|KEEP_WITHIN_PLACEHOLDER|$KEEP_WITHIN|g" "$script_path"
    sed -i "s|KEEP_MONTHLY_PLACEHOLDER|$KEEP_MONTHLY|g" "$script_path"

    chmod +x "$script_path"
    echo "      Created $script_path"
}

if [ "$ENABLE_LOCAL" = "yes" ]; then
    create_backup_script "$LOCAL_REPO" "local"
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    create_backup_script "$REMOTE_REPO" "remote"
fi

echo "      Done."

# ---- Create cron jobs ----
echo ""
echo "[6/6] Setting up cron jobs..."

# Get current crontab, remove old borg-backup entries, add new ones
TEMP_CRON=$(mktemp)
crontab -l 2>/dev/null | grep -v "# borg-backup-" > "$TEMP_CRON" || true

if [ "$ENABLE_LOCAL" = "yes" ]; then
    echo "$LOCAL_CRON_SCHEDULE /etc/backups/run-local.sh >> /var/log/borg-local.log 2>&1 # borg-backup-local" >> "$TEMP_CRON"
    echo "      Added local backup cron job: $LOCAL_CRON_SCHEDULE"
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo "$REMOTE_CRON_SCHEDULE /etc/backups/run-remote.sh >> /var/log/borg-remote.log 2>&1 # borg-backup-remote" >> "$TEMP_CRON"
    echo "      Added remote backup cron job: $REMOTE_CRON_SCHEDULE"
fi

crontab "$TEMP_CRON"
rm "$TEMP_CRON"

# Update cron
/usr/local/sbin/update_cron

echo "      Done."

# ---- Create User Scripts (optional, for GUI management) ----
echo ""
echo "[OPTIONAL] Creating User Scripts for GUI management..."

create_user_script() {
    local name=$1
    local script_dir="/boot/config/plugins/user.scripts/scripts/borg_backup_${name}"

    if [ ! -d /boot/config/plugins/user.scripts ]; then
        echo "      User Scripts plugin not installed, skipping GUI scripts"
        return
    fi

    mkdir -p "$script_dir"

    cat > "$script_dir/script" << 'EOF'
#!/bin/bash
/etc/backups/run-NAME_PLACEHOLDER.sh
EOF
    sed -i "s|NAME_PLACEHOLDER|$name|g" "$script_dir/script"
    chmod +x "$script_dir/script"

    cat > "$script_dir/description" << EOF
Borg ${name} backup - runs /etc/backups/run-${name}.sh
EOF

    echo "      Created User Script: borg_backup_${name}"
}

if [ "$ENABLE_LOCAL" = "yes" ]; then
    create_user_script "local"
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    create_user_script "remote"
fi

# ---- Summary ----
echo ""
echo "============================================================"
echo " Setup complete!"
echo "============================================================"
echo " Passphrase file: /etc/backups/passphrase"
echo ""

if [ "$ENABLE_LOCAL" = "yes" ]; then
    echo " Local Backup:"
    echo "   Script:      /etc/backups/run-local.sh"
    echo "   Repository:  $LOCAL_REPO"
    echo "   Key backup:  /boot/config/borg-local-repo.key (PERSISTENT)"
    echo "   Key backup:  /root/borg-local-repo.key (temporary)"
    echo "   Cron:        $LOCAL_CRON_SCHEDULE"
    echo "   Log:         /var/log/borg-local.log"
    echo ""
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo " Remote Backup:"
    echo "   Script:      /etc/backups/run-remote.sh"
    echo "   Repository:  $REMOTE_REPO"
    echo "   Key backup:  /boot/config/borg-remote-repo.key (PERSISTENT)"
    echo "   Key backup:  /root/borg-remote-repo.key (temporary)"
    echo "   Cron:        $REMOTE_CRON_SCHEDULE"
    echo "   Log:         /var/log/borg-remote.log"
    echo ""
fi

echo "============================================================"
echo " CRITICAL: BACK UP THESE CREDENTIALS NOW!"
echo "============================================================"
echo ""
echo " Your Passphrase:"
echo " ----------------"
echo " $BORG_PASSPHRASE"
echo ""

if [ "$ENABLE_LOCAL" = "yes" ]; then
    echo " Local Repository Key:"
    echo " ---------------------"
    if [ -f /boot/config/borg-local-repo.key ]; then
        cat /boot/config/borg-local-repo.key
    else
        echo " ERROR: Key file not found at /boot/config/borg-local-repo.key"
        echo " You can manually export it with:"
        echo " BORG_PASSCOMMAND=\"cat /etc/backups/passphrase\" borg key export $LOCAL_REPO /boot/config/borg-local-repo.key"
    fi
    echo ""
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo " Remote Repository Key:"
    echo " ----------------------"
    if [ -f /boot/config/borg-remote-repo.key ]; then
        cat /boot/config/borg-remote-repo.key
    else
        echo " ERROR: Key file not found at /boot/config/borg-remote-repo.key"
        echo " You can manually export it with:"
        echo " BORG_PASSCOMMAND=\"cat /etc/backups/passphrase\" borg key export $REMOTE_REPO /boot/config/borg-remote-repo.key"
    fi
    echo ""
fi

echo " IMPORTANT: Store the passphrase and ALL key files"
echo " in a secure location (password manager, encrypted USB, etc)."
echo " You MUST have BOTH the passphrase AND the correct key file"
echo " to recover your backups if this system fails."
echo ""
echo " NOTE: Keys are saved to /boot/config/ which persists across"
echo " reboots. Files in /etc/ and /root/ are temporary and will be"
echo " lost on reboot unless you make them persistent!"
echo ""
echo "============================================================"
echo " Unraid Persistence Note"
echo "============================================================"
echo " Unraid boots from RAM, so most files are temporary."
echo " The following have been made persistent:"
echo "   - Repository keys in /boot/config/"
echo "   - Cron jobs (via update_cron)"
echo "   - User Scripts (if plugin installed)"
echo ""
echo " The following are TEMPORARY and lost on reboot:"
echo "   - /etc/backups/ (passphrase and scripts)"
echo "   - /root/borg-*-repo.key"
echo ""
echo " To make /etc/backups persistent, add to your go file:"
echo "   mkdir -p /etc/backups"
echo "   cp /boot/config/passphrase /etc/backups/"
echo "   cp /boot/config/run-*.sh /etc/backups/"
echo "   chmod 600 /etc/backups/passphrase"
echo "   chmod +x /etc/backups/run-*.sh"
echo ""
echo " OR re-run this script after each reboot."
echo " OR use User Scripts to run backups instead of cron."
echo "============================================================"
echo ""
echo " Next Steps:"
echo " 1. SAVE the passphrase and keys shown above to a safe place"
echo " 2. Test the backup manually:"
if [ "$ENABLE_LOCAL" = "yes" ]; then
    echo "      /etc/backups/run-local.sh"
fi
if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo "      /etc/backups/run-remote.sh"
fi
echo " 3. Check the logs:"
if [ "$ENABLE_LOCAL" = "yes" ]; then
    echo "      tail -f /var/log/borg-local.log"
fi
if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo "      tail -f /var/log/borg-remote.log"
fi
echo " 4. Verify cron schedule: crontab -l"
echo "============================================================"
