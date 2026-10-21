
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Read WHITELIST from .env if it isn't already exported.
if [[ -z "${WHITELIST:-}" ]]; then
    if [[ ! -f .env ]]; then
        echo "ERROR: .env not found" >&2
        exit 1
    fi

    WHITELIST=$(sed -n 's/^WHITELIST=//p' .env | tail -n 1)
    WHITELIST="${WHITELIST%$'\r'}"
    WHITELIST="${WHITELIST#\"}"
    WHITELIST="${WHITELIST%\"}"
    WHITELIST="${WHITELIST#\'}"
    WHITELIST="${WHITELIST%\'}"
fi

if [[ -z "$WHITELIST" ]]; then
    echo "ERROR: WHITELIST is missing or empty" >&2
    exit 1
fi

# Check required tools.
for cmd in md5sum xxd; do
    command -v "$cmd" >/dev/null || {
        echo "ERROR: Missing required command: $cmd" >&2
        exit 1
    }
done

mkdir -p server-data
output="server-data/whitelist.json"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

printf '[\n' > "$tmp"
first=true

IFS=',' read -ra players <<< "$WHITELIST"

for raw_name in "${players[@]}"; do
    name="${raw_name//[[:space:]]/}"

    [[ -z "$name" ]] && continue

    if [[ ${#name} -gt 16 || ! "$name" =~ ^[A-Za-z0-9_]+$ ]]; then
        echo "ERROR: Invalid Minecraft username: $name" >&2
        exit 1
    fi

    # Offline UUID = MD5("OfflinePlayer:" + exact username)
    hex=$(printf 'OfflinePlayer:%s' "$name" | md5sum | cut -d' ' -f1)

    # Set UUID version 3 in the third group.
    hex="${hex:0:12}3${hex:13}"

    # Set RFC 4122 variant bits in the fourth group.
    nibble=$((16#${hex:16:1}))
    variant=$(( (nibble & 3) | 8 ))
    hex="${hex:0:16}$(printf '%x' "$variant")${hex:17}"

    uuid="${hex:0:8}-${hex:8:4}-${hex:12:4}-${hex:16:4}-${hex:20:12}"

    if [[ "$first" != true ]]; then
        printf ',\n' >> "$tmp"
    fi
    first=false

    printf '  {"uuid":"%s","name":"%s"}' "$uuid" "$name" >> "$tmp"
done

printf '\n]\n' >> "$tmp"

if [[ "$first" == true ]]; then
    echo "ERROR: No usernames found" >&2
    exit 1
fi

mv "$tmp" "$output"
trap - EXIT

echo "Whitelist generated: $output"

