
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Read a variable from .env if it isn't already exported.
read_env() {
    local var="$1"
    local value="${!var:-}"

    if [[ -z "$value" ]]; then
        if [[ ! -f .env ]]; then
            echo "ERROR: .env not found" >&2
            exit 1
        fi

        value=$(sed -n "s/^${var}=//p" .env | tail -n 1)
        value="${value%$'\r'}"
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
    fi

    echo "$value"
}

WHITELIST=$(read_env WHITELIST)
OPS=$(read_env OPS)

# Check required tools.
for cmd in md5sum; do
    command -v "$cmd" >/dev/null || {
        echo "ERROR: Missing required command: $cmd" >&2
        exit 1
    }
done

mkdir -p server-data

# Generate offline UUID for a username.
offline_uuid() {
    local name="$1"
    local hex

    hex=$(printf 'OfflinePlayer:%s' "$name" | md5sum | cut -d' ' -f1)

    # Set UUID version 3.
    hex="${hex:0:12}3${hex:13}"

    # Set RFC 4122 variant bits.
    local nibble=$((16#${hex:16:1}))
    local variant=$(( (nibble & 3) | 8 ))
    hex="${hex:0:16}$(printf '%x' "$variant")${hex:17}"

    printf '%s-%s-%s-%s-%s' \
        "${hex:0:8}" \
        "${hex:8:4}" \
        "${hex:12:4}" \
        "${hex:16:4}" \
        "${hex:20:12}"
}

# Validate username.
validate_username() {
    local name="$1"

    if [[ ${#name} -gt 16 || ! "$name" =~ ^[A-Za-z0-9_]+$ ]]; then
        echo "ERROR: Invalid Minecraft username: $name" >&2
        exit 1
    fi
}

# Generate JSON for whitelist or operators.
generate_json() {
    local input="$1"
    local output="$2"
    local type="$3"

    if [[ -z "$input" ]]; then
        echo "ERROR: $type is missing or empty" >&2
        exit 1
    fi

    local tmp
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' RETURN

    printf '[\n' > "$tmp"
    local first=true

    IFS=',' read -ra players <<< "$input"

    for raw_name in "${players[@]}"; do
        local name="${raw_name//[[:space:]]/}"

        [[ -z "$name" ]] && continue

        validate_username "$name"

        local uuid
        uuid=$(offline_uuid "$name")

        if [[ "$first" != true ]]; then
            printf ',\n' >> "$tmp"
        fi
        first=false

        if [[ "$type" == "OPS" ]]; then
            printf '  {"uuid":"%s","name":"%s","level":4,"bypassesPlayerLimit":false}' \
                "$uuid" "$name" >> "$tmp"
        else
            printf '  {"uuid":"%s","name":"%s"}' \
                "$uuid" "$name" >> "$tmp"
        fi
    done

    if [[ "$first" == true ]]; then
        echo "ERROR: No usernames found in $type" >&2
        rm -f "$tmp"
        return 1
    fi

    printf '\n]\n' >> "$tmp"
    mv "$tmp" "$output"

    echo "$type generated: $output"
}

# Generate both files.
generate_json "$WHITELIST" "server-data/whitelist.json" "WHITELIST"
generate_json "$OPS" "server-data/ops.json" "OPS"
