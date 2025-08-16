#!/bin/bash

# Usage: ./generate-envoy-config.sh <endpoint-url> [timeout] [per_try_timeout] [num_retries]

set -e

# Ensure Envoy is installed
if ! command -v envoy &> /dev/null; then
    echo "Envoy is not installed. Installing..."
    sudo apt-get install envoy=1.31.0
    echo "Envoy installed successfully."
fi

TEMPLATE="./templates/envoy_config_hostrewrite_2.yaml"
OUTPUT="envoy-final.yaml"

FULL_URL="$1"
TIMEOUT="${2:-300s}"
PER_TRY_TIMEOUT="${3:-300s}"
NUM_RETRIES="${4:-3}"

if [[ -z "$FULL_URL" ]]; then
  echo "Usage: $0 <endpoint-url> [timeout] [per_try_timeout] [num_retries]"
  exit 1
fi

# Remove protocol (http:// or https://)
URL_NO_PROTO=${FULL_URL#*://}

# Strip trailing slash if any
URL_NO_PROTO=${URL_NO_PROTO%%/}

# Extract host and port
HOSTPORT=${URL_NO_PROTO%%/*}          # remove path, keep host:port
HOST=${HOSTPORT%%:*}                  # before colon
PORT=${HOSTPORT##*:}                  # after colon
[[ "$HOST" == "$PORT" ]] && PORT=443  # if no colon was present, assume 443

# Extract account name (everything before first dot)
ACCOUNT_NAME=${HOST%%.*}

# Replace placeholders
sed \
  -e "s|{{ACCOUNT_NAME}}|$ACCOUNT_NAME|g" \
  -e "s|{{ENDPOINT}}|$HOST|g" \
  -e "s|{{PORT}}|$PORT|g" \
  -e "s|{{TIMEOUT}}|$TIMEOUT|g" \
  -e "s|{{PER_TRY_TIMEOUT}}|$PER_TRY_TIMEOUT|g" \
  -e "s|{{NUM_RETRIES}}|$NUM_RETRIES|g" \
  "$TEMPLATE" > "$OUTPUT"

echo "✅ Generated Envoy config at $OUTPUT"
echo "   - Account: $ACCOUNT_NAME"
echo "   - Host: $HOST"
echo "   - Port: $PORT"
