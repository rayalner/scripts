#!/bin/bash

# ================================
# Move Docker's data-root to /datadisk/docker
#ASSUME: datadisk is mounted and ready to go, and docker is in the default location.
# ================================

set -e

# === CONFIGURATION ===
NEW_ROOT="/datadisk/docker"
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_DIR="/var/lib/docker.bak.$(date +%s)"

echo "🛠️ Starting Docker data move to $NEW_ROOT..."

# 1. Check if /datadisk is mounted
if ! mount | grep -q "/datadisk"; then
    echo "❌ /datadisk is not mounted. Aborting."
    exit 1
fi

# 2. Stop Docker
echo "🛑 Stopping Docker..."
sudo systemctl stop docker

# 3. Copy old Docker data
echo "📁 Copying existing Docker data to $NEW_ROOT..."
sudo mkdir -p "$NEW_ROOT"
sudo rsync -aP /var/lib/docker/ "$NEW_ROOT"

# 4. Backup old Docker directory
echo "📦 Backing up /var/lib/docker to $BACKUP_DIR..."
sudo mv /var/lib/docker "$BACKUP_DIR"

# 5. Write new Docker config
echo "⚙️ Writing new Docker daemon.json to use $NEW_ROOT..."
sudo mkdir -p /etc/docker
echo "{
  \"data-root\": \"$NEW_ROOT\"
}" | sudo tee "$DAEMON_JSON" > /dev/null

# 6. Start Docker
echo "🚀 Restarting Docker..."
sudo systemctl daemon-reexec
sudo systemctl start docker

# 7. Confirm
echo "✅ Docker Root Dir now set to:"
docker info | grep "Docker Root Dir"

echo "🧹 Reminder: if everything is working, you can remove $BACKUP_DIR"
