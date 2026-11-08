
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
echo "[1/4] Stopping Minecraft..."
sudo docker compose stop -t 120 minecraft

# 2. Create a compressed backup of the active world.
echo "[2/4] Creating world backup..."
tar -czf "$BACKUP_FILE" -C server-data world

# 3. Retain only the three newest automatic world backups.
echo "[3/4] Keeping the three newest local backups..."

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

# 4. Sync local backups to Google Drive.
echo "[4/4] Syncing backups to Google Drive..."
rclone sync "$BACKUP_DIR" "$DRIVE_DIR" --progress

echo
echo "======================================"
echo " Server stopped and backup synced!"
echo " Latest backup: $BACKUP_FILE"
echo " Google Drive: $DRIVE_DIR"
echo " Local rolling backups retained: 3"
echo "======================================"
