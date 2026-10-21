# Acacia Nagar Minecraft Server

A self-hosted Minecraft Java Edition server running with Docker Compose, Paper, and Tailscale on Ubuntu under WSL2.

## Requirements

- Windows with WSL2 and Ubuntu
- Docker Engine and Docker Compose
- A Tailscale account
- Minecraft Java Edition
- A Minecraft world backup, if migrating an existing world

## Project Structure

```text
acacia_nagar/
├── compose.yaml
├── .env                  # Local secrets; never commit
├── .env.example          # Safe environment template
├── .gitignore
├── README.md
├── start.sh
├── stop.sh
├── build-whitelist.sh
├── world/                # Original world during migration
├── server-data/          # Active Minecraft server data
├── ts-state/             # Tailscale state; never commit
└── backups/              # World archives; never commit
```

## 1. Initial Setup

Navigate to the project directory:

```bash
cd ~/minecraft-servers/acacia_nagar
```

Make the scripts executable:

```bash
chmod +x start.sh stop.sh build-whitelist.sh
```

Create `.env` from the example template if needed:

```bash
cp .env.example .env
nano .env
```

Configure your own Tailscale authentication key and Minecraft whitelist. Never commit `.env` or share its contents.

## 2. Start the Server

Start Minecraft and Tailscale in the background:

```bash
./start.sh
```

Alternatively, use Docker Compose directly:

```bash
sudo docker compose up -d
```

Check running containers:

```bash
sudo docker compose ps
```

View Minecraft logs:

```bash
sudo docker logs -f minecraft-paper
```

Press `Ctrl+C` to stop following the logs. This does not stop the server.

## 3. Stop the Server and Back Up the World

Run:

```bash
./stop.sh
```

The script should:

1. Stop Minecraft gracefully.
2. Stop Tailscale.
3. Create a timestamped archive of `server-data/world`.
4. Keep the five most recent `world-*.tar.gz` backups.
5. Preserve other archives, including the original Aternos backup.

Backups are stored in:

```text
backups/
```

List them:

```bash
ls -lh backups/
```

**Important:** Verify that the backup completed successfully before deleting or changing any world data.

## 4. Back Up the Original Aternos World

To create a backup of the original world:

```bash
tar -czf backups/acacia-nagar-backup.tar.gz world
```

This archives the `world/` directory in the project root.

List the archive contents:

```bash
tar -tzf backups/acacia-nagar-backup.tar.gz | head -30
```

## 5. Restore a World Backup

Stop Minecraft before restoring any world data:

```bash
sudo docker compose stop minecraft
```

Inspect the archive first:

```bash
tar -tzf backups/acacia-nagar-backup.tar.gz | head -30
```

If the archive contains a top-level `world/` directory, restore it into the active server-data directory:

```bash
mkdir -p server-data
tar -xzf backups/acacia-nagar-backup.tar.gz -C server-data
```

This extracts the archive to `server-data/world`.

**Do not extract over an existing active world without preserving it first.** Move the existing directory to a separate backup name before restoring.

## 6. World Migration

The active world directory is:

```text
server-data/world/
```

The Compose configuration uses:

```yaml
LEVEL: "world"
volumes:
  - ./server-data:/data
```

Therefore, Minecraft loads `/data/world`, which maps to `server-data/world` on the host.

If the original world is in the project-root `world/` directory and you have verified that the active world is backed up, you can move it into place:

```bash
mv world server-data/world
```

Do not run this command if `server-data/world` already exists. Preserve the existing directory first.

Fix ownership and permissions if needed:

```bash
sudo chown -R 1000:1000 server-data
sudo chmod -R u+rwX server-data
```

These commands assume the container uses UID/GID 1000 for its Minecraft files.

Start the server again:

```bash
./start.sh
```

Check the logs for world-loading or migration errors:

```bash
sudo docker logs --tail 100 minecraft-paper
```

### Version Compatibility

Avoid changing Minecraft versions unexpectedly. The configuration currently uses `VERSION: "LATEST"`, which can select a newer version during a rebuild.

Before upgrading:

1. Stop the server.
2. Create a verified backup.
3. Check Paper and plugin compatibility.
4. Upgrade intentionally.
5. Test the world before deleting old backups.

Downgrading a world after a version upgrade is not reliably safe.

## 7. Tailscale and Multiplayer

The server shares the Tailscale container's network namespace.

Check Tailscale connectivity:

```bash
sudo docker logs --tail 100 minecraft-tailscale
```

Friends with authorized Tailscale access can connect to the server using its Tailscale IP and port:

```text
TAILSCALE_IP:25565
```

For local play on the host PC, use:

```text
localhost:25565
```

The Compose configuration must publish the Minecraft port on the `tailscale` service if local host access through the published port is required:

```yaml
ports:
  - "25565:25565"
```

No router port forwarding is required for connections over Tailscale.

### Security

The current server uses `ONLINE_MODE: "FALSE"`. Minecraft usernames are not authenticated in offline mode, so a whitelist alone does not securely establish player identity.

Keep access restricted to trusted users. Do not grant operator privileges casually or expose this configuration publicly.

## 8. Whitelist and Operator Permissions

Generate the whitelist, if required by the project setup:

```bash
./build-whitelist.sh
```

Operator permissions can be configured with the `OPS` environment variable in the Minecraft service:

```yaml
OPS: "NotSaikat"
```

Multiple usernames can be comma-separated:

```yaml
OPS: "NotSaikat,Madhu"
```

Apply configuration changes:

```bash
sudo docker compose up -d
```

For an already-running server, use the server console or configured RCON interface for runtime commands when appropriate.

## 9. Docker and WSL2

Check Docker:

```bash
sudo systemctl status docker
```

Start Docker if necessary:

```bash
sudo systemctl enable --now docker
```

Closing the Ubuntu terminal does not necessarily stop the server. However, if WSL2 shuts down, Docker and Minecraft inside WSL2 stop as well.

Reopen Ubuntu and run:

```bash
cd ~/minecraft-servers/acacia_nagar
./start.sh
```

## 10. Git Safety

Commit infrastructure and documentation, not live game data or credentials.

Recommended `.gitignore` entries:

```gitignore
.env
.env.*
!.env.example

server-data/
world/
world-generated-backup/
ts-state/
backups/

*.log
*.tmp
*.swp
*~
```

Check before committing:

```bash
git status --short
```

Commit the project files:

```bash
git add README.md compose.yaml .gitignore \
  .env.example start.sh stop.sh build-whitelist.sh

git commit -m "Document Minecraft server setup"
```

Never commit `.env`, Tailscale state, world files, or backups. If a secret is accidentally committed or exposed, rotate it. Adding a file to `.gitignore` does not remove it from Git history.

## Quick Reference

| Task | Command |
|---|---|
| Start services | `./start.sh` |
| Stop and back up | `./stop.sh` |
| Check containers | `sudo docker compose ps` |
| Follow Minecraft logs | `sudo docker logs -f minecraft-paper` |
| List backups | `ls -lh backups/` |
| Inspect backup contents | `tar -tzf backups/acacia-nagar-backup.tar.gz` |
| Check Docker | `sudo systemctl status docker` |

Keep at least one verified backup outside the WSL virtual disk. This protects the world if the WSL installation or Windows storage fails.
