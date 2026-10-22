
#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

BACKUP_DIR="backups"
DRIVE_DIR="gdrive:Minecraft/backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_FILE="$BACKUP_DIR/world-$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "======================================"
echo " Acacia Nagar Minecraft Server Stop"
echo "======================================"

# 1. Stop Minecraft gracefully.
echo "[1/5] Stopping Minecraft..."
sudo docker compose stop -t 120 minecraft

# 2. Stop Tailscale.
echo "[2/5] Stopping Tailscale..."
sudo docker compose stop tailscale

# 3. Create a compressed backup of the active world.
echo "[3/5] Creating world backup..."
tar -czf "$BACKUP_FILE" -C server-data world

# 4. Retain only the five newest automatic world backups.
echo "[4/5] Keeping the five newest local backups..."

mapfile -t OLD_BACKUPS < <(
    find "$BACKUP_DIR" -maxdepth 1 -type f \
        -name 'world-*.tar.gz' -printf '%T@ %p\n' |
        sort -nr |
        tail -n +4 |
        cut -d' ' -f2-
)

for file in "${OLD_BACKUPS[@]}"; do
    [[ -z "$file" ]] || rm -v -- "$file"
done

# 5. Sync local backups to Google Drive.
echo "[5/5] Syncing backups to Google Drive..."
rclone sync "$BACKUP_DIR" "$DRIVE_DIR" --progress

echo
echo "======================================"
echo " Server stopped and backup synced!"
echo " Latest backup: $BACKUP_FILE"
echo " Google Drive: $DRIVE_DIR"
echo " Local backups retained: 5"
echo "======================================"

