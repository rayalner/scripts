#!/bin/bash
# ============================================================
# Borg Backup Setup Script
# Run as root: sudo bash borg-setup.sh
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
    echo "ERROR: Please run as root: sudo bash borg-setup.sh"
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

if [ -f /etc/systemd/system/borg-backup-local.timer ] || [ -f /etc/systemd/system/borg-backup-remote.timer ]; then
    EXISTING_INSTALL=yes
    WARNINGS="${WARNINGS}\n  - Systemd timers and services will be overwritten"
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
echo " Borg Backup Setup"
echo "============================================================"
echo " Sources:     $BACKUP_SOURCES"
echo " Compression: $COMPRESSION"
echo ""
if [ "$ENABLE_LOCAL" = "yes" ]; then
    echo " Local Backup:  ENABLED"
    echo "   Repository:  $LOCAL_REPO"
    echo "   Schedule:    $LOCAL_SCHEDULE_TIME on day(s) $LOCAL_SCHEDULE_DAYS"
else
    echo " Local Backup:  DISABLED"
fi
echo ""
if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo " Remote Backup: ENABLED"
    echo "   Repository:  $REMOTE_REPO"
    echo "   Schedule:    $REMOTE_SCHEDULE_TIME on day(s) $REMOTE_SCHEDULE_DAYS"
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
if command -v dnf &>/dev/null; then
    dnf install -y borgbackup
elif command -v apt-get &>/dev/null; then
    apt-get install -y borgbackup
else
    echo "ERROR: Could not detect package manager. Install borgbackup manually then re-run."
    exit 1
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
    echo "      Exporting repo key to /root/borg-${name}-repo.key (keep this safe!)..."
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

    cat > "$script_path" << EOF
#!/bin/bash -ue

export BORG_PASSCOMMAND="cat /etc/backups/passphrase"
export BORG_RELOCATED_REPO_ACCESS_IS_OK=no
export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=no

TARGET=$repo
DATE=\$(date --iso-8601)-\$(hostname)

echo "Starting Borg ${name} backup: \$DATE"
borg --version

borg create \\
  --stats \\
  --one-file-system \\
  --compression $COMPRESSION \\
  --checkpoint-interval 86400 \\
  \$TARGET::\$DATE \\
  $BACKUP_SOURCES

borg prune \\
  --keep-within $KEEP_WITHIN \\
  --keep-monthly $KEEP_MONTHLY \\
  \$TARGET

sync
echo "Backup complete."
EOF

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

# ---- Create systemd services and timers ----
echo ""
echo "[6/6] Creating systemd services and timers..."

create_systemd_units() {
    local name=$1
    local schedule_days=$2
    local schedule_time=$3

    # Backup existing units if they exist
    if [ -f "/etc/systemd/system/borg-backup-${name}.service" ]; then
        cp "/etc/systemd/system/borg-backup-${name}.service" \
           "/etc/systemd/system/borg-backup-${name}.service.bak.$(date +%Y%m%d-%H%M%S)"
    fi
    if [ -f "/etc/systemd/system/borg-backup-${name}.timer" ]; then
        cp "/etc/systemd/system/borg-backup-${name}.timer" \
           "/etc/systemd/system/borg-backup-${name}.timer.bak.$(date +%Y%m%d-%H%M%S)"
    fi

    cat > "/etc/systemd/system/borg-backup-${name}.service" << EOF
[Unit]
Description=Borg Backup (${name})

[Service]
Type=oneshot
ExecStart=/etc/backups/run-${name}.sh
EOF

    cat > "/etc/systemd/system/borg-backup-${name}.timer" << EOF
[Unit]
Description=Borg Backup Timer (${name})

[Timer]
OnCalendar=*-*-${schedule_days} ${schedule_time}
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now "borg-backup-${name}.timer"
    echo "      Created and enabled borg-backup-${name}.timer"
}

if [ "$ENABLE_LOCAL" = "yes" ]; then
    create_systemd_units "local" "$LOCAL_SCHEDULE_DAYS" "$LOCAL_SCHEDULE_TIME"
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    create_systemd_units "remote" "$REMOTE_SCHEDULE_DAYS" "$REMOTE_SCHEDULE_TIME"
fi

echo "      Done."

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
    echo "   Key backup:  /root/borg-local-repo.key"
    echo ""
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo " Remote Backup:"
    echo "   Script:      /etc/backups/run-remote.sh"
    echo "   Repository:  $REMOTE_REPO"
    echo "   Key backup:  /root/borg-remote-repo.key"
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
    if [ -f /root/borg-local-repo.key ]; then
        cat /root/borg-local-repo.key
    else
        echo " ERROR: Key file not found at /root/borg-local-repo.key"
        echo " You can manually export it with:"
        echo " sudo bash -c 'BORG_PASSCOMMAND=\"cat /etc/backups/passphrase\" borg key export $LOCAL_REPO /root/borg-local-repo.key'"
    fi
    echo ""
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    echo " Remote Repository Key:"
    echo " ----------------------"
    if [ -f /root/borg-remote-repo.key ]; then
        cat /root/borg-remote-repo.key
    else
        echo " ERROR: Key file not found at /root/borg-remote-repo.key"
        echo " You can manually export it with:"
        echo " sudo bash -c 'BORG_PASSCOMMAND=\"cat /etc/backups/passphrase\" borg key export $REMOTE_REPO /root/borg-remote-repo.key'"
    fi
    echo ""
fi

echo " IMPORTANT: Store the passphrase and ALL key files"
echo " in a secure location (password manager, encrypted USB, etc)."
echo " You MUST have BOTH the passphrase AND the correct key file"
echo " to recover your backups if this system fails."
echo ""
echo "============================================================"
echo " Next scheduled backups:"
echo "============================================================"

if [ "$ENABLE_LOCAL" = "yes" ]; then
    systemctl list-timers borg-backup-local.timer --no-pager
fi

if [ "$ENABLE_REMOTE" = "yes" ]; then
    systemctl list-timers borg-backup-remote.timer --no-pager
fi

echo "============================================================"
