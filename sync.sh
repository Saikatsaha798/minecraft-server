
#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

DRIVE_DIR="gdrive:Minecraft/backups"
DATA_DIR="server-data"
WORLD_DIR="$DATA_DIR/world"
BACKUP_DIR="backups"

mkdir -p "$BACKUP_DIR" "$DATA_DIR"

# Never restore while Minecraft is running.
if sudo docker inspect -f '{{.State.Running}}' minecraft-paper 2>/dev/null |
   grep -q true; then
    echo "ERROR: Minecraft is running. Stop it before restoring."
    exit 1
fi

echo "Finding the latest Google Drive backup..."

LATEST="$(
    rclone lsf "$DRIVE_DIR" --files-only |
    grep -E '^world-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.tar\.gz$' |
    sort -r |
    head -n 1
)"

if [[ -z "$LATEST" ]]; then
    echo "ERROR: No timestamped world backups found in Google Drive."
    exit 1
fi

echo "Selected backup: $LATEST"

# If a world already exists, preserve it by default.
if [[ -d "$WORLD_DIR" && "${1:-}" != "--restore" ]]; then
    echo "Local world already exists. Keeping it unchanged."
    echo "To deliberately restore the cloud backup, run:"
    echo "./sync.sh --restore"
    exit 0
fi

TEMP_FILE="$(mktemp)"
trap 'rm -f "$TEMP_FILE"' EXIT

echo "Downloading backup..."
rclone copyto "$DRIVE_DIR/$LATEST" "$TEMP_FILE"

echo "Verifying archive..."
tar -tzf "$TEMP_FILE" >/dev/null

# Make a safety copy before replacing an existing world.
if [[ -d "$WORLD_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    SAFETY="$BACKUP_DIR/world-before-restore-$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    echo "Preserving current world: $SAFETY"
    tar -czf "$SAFETY" -C "$DATA_DIR" world
fi

echo "Restoring world..."
rm -rf "$WORLD_DIR"
tar -xzf "$TEMP_FILE" -C "$DATA_DIR"

sudo chown -R 1000:1000 "$WORLD_DIR"

echo "World restored successfully from $LATEST"
