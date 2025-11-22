#!/usr/bin/env bash
set -euo pipefail

# Required env vars:
#   NAT_HOST        - NATS server URL (ex: nats://localhost:4222)
#   PG_CONNECTION   - Postgres connection string (ex: "postgres://user:pass@host/db")
#   PG_CHANNEL      - Channel name for pg_notify
#   HEALTH_TIMEOUT  - Timeout in seconds (default: 5)

if [[ -z "${NAT_HOST:-}" || -z "${PG_CONNECTION:-}" || -z "${PG_CHANNEL:-}" ]]; then
  echo "Missing required environment variables."
  exit 1
fi

TIMEOUT="${HEALTH_TIMEOUT:-5}"
FIFO=$(mktemp -u)
NATS_PID=""
CLEANUP() {
  if [[ -n "$NATS_PID" ]]; then
    kill "$NATS_PID" 2>/dev/null || true
    wait "$NATS_PID" 2>/dev/null || true
  fi
  [[ -p "$FIFO" ]] && rm -f "$FIFO"
}
trap CLEANUP EXIT INT TERM

# Create FIFO for inter-process communication
mkfifo "$FIFO"

# Start NATS subscriber in background
nats sub healthcheck --server "$NAT_HOST" > "$FIFO" 2>/dev/null &
NATS_PID=$!

# Give subscriber a moment to connect and verify it's running
sleep 0.5
if ! kill -0 "$NATS_PID" 2>/dev/null; then
  echo "Failed to start NATS subscriber"
  exit 1
fi

# Issue pg_notify to trigger health check
if ! psql "$PG_CONNECTION" \
  -c "SELECT pg_notify('$PG_CHANNEL', jsonb_build_object('subject','healthcheck')::TEXT);" >/dev/null 2>&1; then
  echo "Failed to send pg_notify"
  exit 1
fi

# Wait for message with timeout (read -t sets timeout in seconds)
if read -t "$TIMEOUT" -r _ < "$FIFO"; then
  exit 0
else
  echo "Health check timed out after ${TIMEOUT}s"
  exit 1
fi
