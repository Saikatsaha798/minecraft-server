# Acacia Nagar Minecraft Server

A self-hosted Minecraft Java Edition server running on Ubuntu under WSL2, using Docker Compose, Paper, and Tailscale for private multiplayer access.

The project includes automated world backups, Google Drive synchronization, and a startup restoration workflow to help preserve the Minecraft world across devices and environments.

## Requirements

- Windows with WSL2 and Ubuntu
- Docker Engine and Docker Compose
- A Tailscale account
- A Google account for Google Drive backups
- `rclone` configured with a Google Drive remote
- Minecraft Java Edition
- An existing Minecraft world backup (if migrating an existing world)

## Project Structure

```text
acacia_nagar/
├── compose.yaml
├── .env                  # Local secrets; never commit
├── .env.example          # Safe environment template
├── .gitignore
├── README.md
├── start.sh              # Checks cloud backup and starts services
├── stop.sh               # Stops services and creates backups
├── sync.sh               # Downloads and restores cloud backups
├── build-whitelist.sh    # Generates whitelist.json
├── world/                # Original Aternos world (migration source)
├── server-data/          # Active Minecraft server data
├── ts-state/             # Persistent Tailscale state
└── backups/              # Local world archives
```

**Important:** `world/`, `server-data/`, `ts-state/`, and `backups/` contain runtime data and should not be committed to Git.

---

## 1. Initial Setup

Navigate to the project directory:

```bash
cd ~/minecraft-servers/acacia_nagar
```

Make the scripts executable:

```bash
chmod +x start.sh stop.sh sync.sh build-whitelist.sh
```

Create the environment configuration:

```bash
cp .env.example .env
nano .env
```

Configure the required environment variables, including your Tailscale authentication key.

Never commit or share `.env`. Keep your Tailscale credentials and other secrets private.

### Google Drive setup

Install and configure `rclone` if you haven't already.

The Google Drive remote used by this project is:

```text
gdrive:Minecraft/backups
```

Verify the connection:

```bash
rclone listremotes
rclone lsd gdrive:Minecraft
rclone lsd gdrive:Minecraft/backups
```

The `gdrive` remote must be configured and authenticated before using cloud synchronization or restoration.

---

## 2. Start the Server

Start the server using:

```bash
./start.sh
```

The startup script performs the following operations:

1. Checks Google Drive for the latest timestamped world backup.
2. Checks whether a local active world already exists.
3. Restores the latest cloud backup only if the local world is missing.
4. Starts Minecraft and Tailscale using Docker Compose.
5. Displays the service status.

**Important:** Normal startup does not overwrite an existing local world.

Alternatively, start the services directly:

```bash
sudo docker compose up -d
```

Check running containers:

```bash
sudo docker compose ps
```

Follow Minecraft logs:

```bash
sudo docker logs -f minecraft-paper
```

Press `Ctrl+C` to stop following the logs. This does not stop the Minecraft server.

---

## 3. Stop the Server and Create Backups

Run:

```bash
./stop.sh
```

The stop script performs the following operations:

1. Gracefully stops Minecraft.
2. Stops the Tailscale container.
3. Creates a timestamped archive of `server-data/world`.
4. Keeps the latest **three rolling world backups** locally.
5. Preserves other archives, including the original Aternos backup.
6. Synchronizes the local backup directory with Google Drive.

### Local backup location

```text
backups/
```

Rolling backup filenames follow this format:

```text
world-YYYY-MM-DD_HH-MM-SS.tar.gz
```

List available backups:

```bash
ls -lh backups/
```

### Backup retention

The project retains three timestamped rolling backups.

For example:

```text
backups/
├── acacia-nagar-backup.tar.gz
├── world-2026-11-06_20-30-00.tar.gz
├── world-2026-11-07_20-30-00.tar.gz
└── world-2026-11-08_20-30-00.tar.gz
```

The original Aternos archive is not included in the rolling cleanup and is preserved separately.

**Important:** Verify that a backup completed successfully before deleting or modifying any world data.

---

## 4. Google Drive Synchronization

The project uses `rclone` to synchronize local backups with Google Drive.

Remote directory:

```text
gdrive:Minecraft/backups
```

The stop script runs:

```bash
rclone sync backups/ gdrive:Minecraft/backups/ --progress
```

This makes the Google Drive directory mirror the local backup directory.

**Warning:** `rclone sync` deletes remote files that are no longer present locally. The original Aternos backup remains synchronized as long as it is retained locally in `backups/`.

### Manually synchronize backups

```bash
rclone sync backups/ gdrive:Minecraft/backups/ --progress
```

### Check Google Drive backups

```bash
rclone lsf gdrive:Minecraft/backups
```

### Restore after losing local world data

The `sync.sh` script downloads the latest timestamped backup from Google Drive.

Normal execution:

```bash
./sync.sh
```

If `server-data/world` already exists, the script leaves it unchanged.

To deliberately replace the local world with the latest cloud backup:

```bash
./sync.sh --restore
```

The restoration workflow:

1. Checks that Minecraft is not running.
2. Finds the latest timestamped backup in Google Drive.
3. Downloads the archive.
4. Verifies the archive.
5. Extracts the world into a temporary staging directory.
6. Creates a safety archive of the existing world, if present.
7. Replaces the active world with the downloaded version.
8. Applies Minecraft file ownership.

The expected active world directory is:

```text
server-data/world/
```

**Never run a manual restoration while Minecraft is running.**

### Google Drive authentication

If the Google Drive token expires or is revoked, reconnect the remote:

```bash
rclone config reconnect gdrive:
```

Then verify the connection:

```bash
rclone lsd gdrive:Minecraft/backups
```

If authorization fails under WSL2, ensure the OAuth browser callback can reach the Ubuntu environment running rclone.

---

## 5. Original Aternos World Backup

The original Aternos world should be preserved separately from the rolling backups.

To create the archive:

```bash
tar -czf backups/acacia-nagar-backup.tar.gz world
```

Inspect its contents:

```bash
tar -tzf backups/acacia-nagar-backup.tar.gz | head -30
```

The archive should contain a top-level `world/` directory.

To restore it into the active server-data directory:

```bash
mkdir -p server-data
tar -xzf backups/acacia-nagar-backup.tar.gz -C server-data
```

This extracts the world to:

```text
server-data/world/
```

**Do not extract over an existing active world without preserving it first.**

Keep the original archive until you have verified the migrated world, player inventories, advancements, statistics, Nether, and End dimensions.

---

## 6. World Migration

The active Minecraft world is located at:

```text
server-data/world/
```

The Compose configuration uses:

```yaml
LEVEL: "world"
volumes:
  - ./server-data:/data
```

Therefore:

| Host directory | Container directory |
|---|---|
| `server-data/` | `/data/` |
| `server-data/world/` | `/data/world/` |

If the original world is still in the project-root `world/` directory, migrate it only after preserving any existing active world.

```bash
mv world server-data/world
```

Do not run this command if `server-data/world` already exists.

### Fix permissions

The following commands assume the Minecraft container runs using UID/GID 1000:

```bash
sudo chown -R 1000:1000 server-data
sudo chmod -R u+rwX server-data
```

Start the server:

```bash
./start.sh
```

Check the logs for world-loading errors:

```bash
sudo docker logs --tail 100 minecraft-paper
```

---

## 7. Minecraft Version Compatibility

The current configuration uses:

```yaml
TYPE: "PAPER"
VERSION: "LATEST"
```

`LATEST` can select a newer Minecraft version when the container is recreated.

For a production world, pin a specific compatible Minecraft version rather than upgrading automatically.

Before upgrading:

1. Stop the server.
2. Create and verify a world backup.
3. Check Paper compatibility.
4. Upgrade intentionally.
5. Test the world and player data.
6. Retain the previous backups until everything is verified.

Downgrading an upgraded Minecraft world is not reliably safe.

---

## 8. Tailscale and Multiplayer

Minecraft shares the Tailscale container's network namespace.

Check Tailscale logs:

```bash
sudo docker logs --tail 100 minecraft-tailscale
```

Friends with authorized Tailscale access can connect using:

```text
TAILSCALE_IP:25565
```

For local play on the host PC:

```text
localhost:25565
```

The Tailscale service must publish the Minecraft port for local host access through Docker's published port:

```yaml
ports:
  - "25565:25565"
```

No router port forwarding is required for connections over Tailscale.

### Security considerations

The server currently uses:

```yaml
ONLINE_MODE: "FALSE"
```

Offline mode does not authenticate Minecraft usernames with Mojang/Microsoft.

Consequently:

- A whitelist alone does not guarantee player identity.
- Players may impersonate other usernames.
- OP privileges should be restricted.
- Access should remain limited to trusted Tailscale users.
- Do not expose the offline-mode server publicly.

---

## 9. Whitelist and Operator Permissions

Generate the whitelist using:

```bash
./build-whitelist.sh
```

Operator permissions can be configured through the Minecraft service's environment:

```yaml
OPS: "NotSaikat"
```

Multiple operators can be specified:

```yaml
OPS: "NotSaikat,Madhu"
```

For an already-running server, use the Minecraft console or configured RCON interface for runtime changes.

For example:

```bash
sudo docker exec minecraft-paper rcon-cli whitelist reload
```

---

## 10. Docker and WSL2 Management

Check Docker status:

```bash
sudo systemctl status docker
```

Start and enable Docker:

```bash
sudo systemctl enable --now docker
```

Closing an Ubuntu terminal does not necessarily stop the Minecraft server.

However, shutting down WSL2 terminates the Ubuntu environment and its running containers.

After reopening Ubuntu:

```bash
cd ~/minecraft-servers/acacia_nagar
./start.sh
```

Check container status:

```bash
sudo docker compose ps
```

---

## 11. Git and Repository Safety

The Git repository should contain infrastructure, scripts, and documentation, not live Minecraft data or credentials.

Recommended `.gitignore`:

```gitignore
# Secrets
.env
.env.*
!.env.example

# Minecraft runtime data
server-data/
world/
world-generated-backup/

# Tailscale state
ts-state/

# Backups
backups/

# Temporary files
*.log
*.tmp
*.swp
*~
```

Check repository status:

```bash
git status --short
```

Stage project files:

```bash
git add README.md compose.yaml .gitignore \
  .env.example start.sh stop.sh sync.sh build-whitelist.sh
```

Commit:

```bash
git commit -m "Document Minecraft server infrastructure and backup workflow"
```

Never commit:

- `.env` or OAuth credentials
- Tailscale state
- Minecraft world data
- Player data
- Local backup archives
- `rclone.conf`

If a secret is accidentally committed or exposed, rotate it. Adding a file to `.gitignore` does not remove it from Git history.

---

## 12. Quick Reference

| Task | Command |
|---|---|
| Start services | `./start.sh` |
| Stop and back up | `./stop.sh` |
| Check containers | `sudo docker compose ps` |
| Follow Minecraft logs | `sudo docker logs -f minecraft-paper` |
| Restore if local world is missing | `./sync.sh` |
| Force cloud restoration | `./sync.sh --restore` |
| List local backups | `ls -lh backups/` |
| List cloud backups | `rclone lsf gdrive:Minecraft/backups` |
| Manually sync backups | `rclone sync backups/ gdrive:Minecraft/backups/ --progress` |
| Check Docker | `sudo systemctl status docker` |
| Reload whitelist | `sudo docker exec minecraft-paper rcon-cli whitelist reload` |

---

## Backup Strategy

The project maintains three layers of protection:

1. **Active world:** `server-data/world/`
2. **Local rolling backups:** Three timestamped archives in `backups/`
3. **Google Drive:** A synchronized copy of the local backup directory

The original Aternos archive is preserved separately from rolling backup cleanup.

For additional protection, periodically keep an independent copy of a verified backup outside the WSL2 virtual disk. This protects against Windows storage failures, WSL corruption, or accidental loss of the entire Ubuntu environment.

**Acacia Nagar: Build, Explore, Preserve.**