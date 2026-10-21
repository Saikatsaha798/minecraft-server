
#!/bin/bash
set -e

cd "$(dirname "$0")"

BACKUP_DIR="backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/world-$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Stopping Minecraft gracefully..."
sudo docker compose stop -t 120 minecraft

echo "Stopping Tailscale..."
sudo docker compose stop tailscale

echo "Creating world backup..."
tar -czvf "$BACKUP_FILE" -C server-data world

echo "Keeping only the 5 latest world backups..."
find "$BACKUP_DIR" -maxdepth 1 -type f \
  -name 'world-*.tar.gz' -printf '%T@ %p\n' |
  sort -nr |
  tail -n +6 |
  cut -d' ' -f2- |
  while IFS= read -r file; do
    [ -z "$file" ] || rm -v -- "$file"
  done

echo "Minecraft and Tailscale stopped."
echo "Backup saved to: $BACKUP_FILE"

