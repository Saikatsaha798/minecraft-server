
#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Starting Minecraft server..."
sudo docker compose up -d

echo "Minecraft server started!"
sudo docker compose ps

