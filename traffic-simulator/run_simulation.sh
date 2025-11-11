#!/bin/bash

# Run PostgreSQL Traffic Simulation
# This script runs the traffic simulator tool with predefined parameters focusing on maximum throughput of select queries.

# Load environment variables
if [ -f ".env" ]; then
    echo "📄 Loading environment variables from .env file..."
    set -a  # automatically export all variables
    source .env
    set +a  # stop automatically exporting
else
    echo "⚠️  No .env file found in traffic-simulator directory"
    echo "💡 Please run setup-env.sh from the project root to copy environment configuration"
    exit 1
fi

# Construct database URL from environment variables
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_NAME" ]; then
    echo "❌ Missing required database environment variables"
    echo "Required: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME"
    echo "Optional: DB_PORT (defaults to 5432)"
    exit 1
fi

DB_PORT=${DB_PORT:-5432}

# URL encode the password to handle special characters in JWT tokens
url_encode() {
    python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# URL encode both username and password (username contains @ symbol)
ENCODED_USER=$(url_encode "$DB_USER")
ENCODED_PASSWORD=$(url_encode "$DB_PASSWORD")
DATABASE_URL="postgresql://${ENCODED_USER}:${ENCODED_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require"

echo "🏗️  Building release binary..."
cargo build --release

echo "🚀 Starting traffic simulation..."
echo "🔗 Connecting to: ${DB_HOST}:${DB_PORT}/${DB_NAME}"

./target/release/postgres-traffic-simulator \
    --database-url "$DATABASE_URL" \
    --query-type select \
    --duration 30 \
    --duration-only \
    --connections 10 \
    --disable-logging