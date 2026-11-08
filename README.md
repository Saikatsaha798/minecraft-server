# Minecraft Paper Server (Docker)

A self-hosted **Minecraft Java Edition Paper server** running in Docker on Ubuntu. The server uses Docker Compose for deployment, shell scripts for startup and backups, and Google Drive for remote world backup storage.

This branch (`dev_0.0.1_wo_vpn`) runs Minecraft **without a Tailscale sidecar container**. Tailscale, if needed, is installed and managed directly on the Ubuntu host.

## Features

- Minecraft Java Edition server powered by Paper
- Docker Compose deployment
- Persistent world data stored on the host
- Automatic world restoration from Google Drive
- Automatic world backups on shutdown
- Three newest automatic local backups retained
- Google Drive backup synchronization using rclone
- Offline-mode whitelist and operator UUID generation
- Optional remote access through host-installed Tailscale
- No VPN container or VPN dependency in Docker Compose

## Architecture

```text
                  Ubuntu Host (home-server)
                 ┌──────────────────────────┐
                 │                          │
                 │  Docker Compose          │
                 │  ┌────────────────────┐  │
Minecraft Client ├─►│  Minecraft Paper   │  │
                 │  │  Container         │  │
                 │  │  Port: 25565      │  │
                 │  └────────────────────┘  │
                 │           │              │
                 │           ▼              │
                 │     ./server-data        │
                 │                          │
                 │  Host-installed Tailscale│
                 │  (optional, independent) │
                 └──────────────────────────┘
                              │
                              ▼
                       Google Drive
                       (rclone backups)
```

The Minecraft container publishes TCP port `25565` directly on the Ubuntu host.

Tailscale is not managed by this Compose project. If installed on the host, it can provide private remote access without router port forwarding.

## Requirements

- Ubuntu Server or another Linux distribution
- Docker Engine
- Docker Compose plugin
- Git
- rclone
- Google Drive account for remote backups
- Minecraft Java Edition client

## Project Structure

```text
minecraft-server/
├── compose.yaml
├── .env
├── .env.example
├── .gitignore
├── README.md
│
├── start.sh
├── stop.sh
├── sync.sh
├── build-whitelist.sh
│
├── server-data/
│   ├── world/
│   ├── whitelist.json
│   ├── ops.json
│   └── ...
│
└── backups/
    ├── world-YYYY-MM-DD_HH-MM-SS.tar.gz
    └── ...
```

The actual contents of `server-data/` depend on the server's runtime state.

## Initial Setup

### 1. Clone the repository

```bash
git clone -b dev_0.0.1_wo_vpn https://github.com/Saikatsaha798/minecraft-server.git

cd minecraft-server
```

### 2. Configure environment variables

Create your `.env` file:

```bash
cp .env.example .env
nano .env
```

Configure your Minecraft usernames:

```env
WHITELIST=NotSaikat,Friend456,Friend789
OPS=NotSaikat
```

Add your Google Drive configuration through rclone separately. Do not put OAuth tokens or passwords in the repository.

### 3. Configure rclone

Run:

```bash
rclone config
```

Create a Google Drive remote named:

```text
gdrive
```

The backup scripts use:

```text
gdrive:Minecraft/backups
```

For a headless Ubuntu server, authenticate rclone using a browser-enabled machine and transfer the authorization token securely.

Verify the remote:

```bash
rclone lsd gdrive:
```

### 4. Prepare the server data

Create the required directories:

```bash
mkdir -p server-data backups
```

If migrating an existing Minecraft world, restore it into:

```text
server-data/world/
```

The world directory should contain files such as:

```text
level.dat
region/
playerdata/
advancements/
DIM-1/
DIM1/
```

Ensure the container can access the files:

```bash
sudo chown -R 1000:1000 server-data
sudo chmod -R u+rwX server-data
```

## Whitelist and Operator Configuration

The `build-whitelist.sh` script reads `WHITELIST` and `OPS` from `.env` and generates:

- `server-data/whitelist.json`
- `server-data/ops.json`

It uses offline-mode UUID generation, so the usernames must match the names players use to join the server, including capitalization.

Run:

```bash
chmod +x build-whitelist.sh
./build-whitelist.sh
```

The generated files are used by the Minecraft server.

**Important:** The Compose configuration should not also pass usernames through the image's `OPS` environment variable if that causes PlayerDB lookups to fail for offline-only usernames. Let the script generate `ops.json` instead.

## Starting the Server

Use:

```bash
./start.sh
```

The startup workflow should:

1. Synchronize or restore the latest world backup using `sync.sh`.
2. Start the Minecraft container using Docker Compose.

To start manually:

```bash
sudo docker compose up -d
```

Check container status:

```bash
sudo docker compose ps
```

View logs:

```bash
sudo docker compose logs -f minecraft
```

## Stopping the Server and Creating Backups

Use:

```bash
./stop.sh
```

The shutdown workflow:

1. Gracefully stops the Minecraft container.
2. Creates a timestamped compressed world backup.
3. Retains the three newest automatic local world backups.
4. Synchronizes the local backup directory to Google Drive.

Backups are stored locally in:

```text
backups/
```

Google Drive destination:

```text
gdrive:Minecraft/backups
```

The backup retention rule applies to automatic files named `world-*.tar.gz`. It does not automatically remove unrelated archives, such as an original migration backup.

**Note:** `rclone sync` mirrors the local backup directory to Google Drive. Files removed locally can also be removed from the remote destination.

## Restoring a World Backup

The `sync.sh` script retrieves the latest timestamped backup from Google Drive.

Normal usage:

```bash
./sync.sh
```

If a world already exists, the script should avoid replacing it by default.

To explicitly restore and replace the existing world:

```bash
./sync.sh --restore
```

The restore process should be performed while Minecraft is stopped.

Before restoring, retain a separate safety backup of any world you want to preserve.

## Remote Access

### Option 1: LAN access

Players on the same local network can connect using the Ubuntu host's LAN IP:

```text
192.168.x.x:25565
```

Replace the IP with the actual address of your Ubuntu server.

### Option 2: Tailscale access

Tailscale can be installed directly on the Ubuntu host. It is independent of Docker Compose in this branch.

After connecting the host to your tailnet, friends with authorized access can connect using:

```text
<Tailscale-IP>:25565
```

No router port forwarding is required for Tailscale access.

If UFW is enabled and you want to allow Minecraft only through Tailscale:

```bash
sudo ufw allow in on tailscale0 to any port 25565 proto tcp
```

Review your other firewall rules as well. Docker's published ports can interact with UFW rules, so verify that the server is not unintentionally exposed on public interfaces.

### Option 3: Public internet access

Public access requires router port forwarding and appropriate firewall configuration.

Only expose the Minecraft TCP port if you understand the security implications. Avoid exposing Docker's management interface or other internal services.

## Docker Management

Run these commands from the project directory.

| Operation | Command |
|---|---|
| Start | `sudo docker compose up -d` |
| Stop | `sudo docker compose stop minecraft` |
| Restart | `sudo docker compose restart minecraft` |
| Status | `sudo docker compose ps` |
| Logs | `sudo docker compose logs -f minecraft` |
| Console | `sudo docker exec -it minecraft-paper rcon-cli` |
| Whitelist reload | `sudo docker exec minecraft-paper rcon-cli whitelist reload` |
| Operator list | `sudo docker exec minecraft-paper rcon-cli op list` |

## Configuration

The Minecraft server configuration is managed through `compose.yaml`.

Common settings include:

| Variable | Purpose |
|---|---|
| `EULA` | Accept Minecraft EULA |
| `TYPE` | Server software, Paper |
| `VERSION` | Minecraft version |
| `MEMORY` | JVM memory allocation |
| `ONLINE_MODE` | Online or offline authentication |
| `LEVEL` | World directory name |
| `ENABLE_WHITELIST` | Enable whitelist |
| `ENFORCE_WHITELIST` | Require whitelist membership |
| `MAX_PLAYERS` | Maximum player count |
| `VIEW_DISTANCE` | Server view distance |
| `SIMULATION_DISTANCE` | Simulation distance |

For a long-running world, consider pinning a specific Minecraft version rather than using `LATEST`. This avoids unexpected version upgrades.

## Security Notes

- This branch does not run a Tailscale container.
- The Minecraft port is published directly on the Ubuntu host.
- Use firewall rules to restrict access to trusted interfaces and networks.
- Do not commit `.env`, OAuth credentials, Tailscale keys, or private configuration files.
- `ONLINE_MODE=FALSE` disables Mojang/Microsoft authentication. Players can potentially impersonate other usernames, so only allow trusted players and restrict network access.
- Keep Docker, Ubuntu, and the Minecraft server image updated.
- Keep independent backups of important worlds.

## Git Workflow

The project uses separate branches for different deployment architectures:

| Branch | Deployment |
|---|---|
| `dev_0.0.1` | Minecraft with a Tailscale sidecar container |
| `dev_0.0.1_wo_vpn` | Minecraft without a Tailscale sidecar container |

Switch to this branch:

```bash
git checkout dev_0.0.1_wo_vpn
```

Before updating the server from Git, stop Minecraft and back up the world. Avoid committing live world files while the server is running.

## Quick Reference

```bash
# Start server
./start.sh

# Check status
sudo docker compose ps

# Follow logs
sudo docker compose logs -f minecraft

# Stop server and back up world
./stop.sh

# Restore latest backup without replacing existing world
./sync.sh

# Force restoration
./sync.sh --restore

# Generate whitelist and operator files
./build-whitelist.sh
```

---

**Deployment:** `dev_0.0.1_wo_vpn`  
**Server software:** Paper  
**Container image:** `itzg/minecraft-server:java25`  
**Container name:** `minecraft-paper`  
**Default Minecraft port:** `25565/TCP`  
**Backup storage:** Local disk + Google Drive  
**VPN architecture:** No VPN sidecar; optional host-installed Tailscale