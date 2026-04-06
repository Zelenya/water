#!/bin/sh

set -eu

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "pg_dump is required but was not found in PATH" >&2
  exit 1
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

backup_dir="${BACKUP_DIR:-backups/dump}"
timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
backup_path="${backup_dir}/water-prod-${timestamp}.dump"

mkdir -p "$backup_dir"

echo "Starting pg_dump to ${backup_path}"

if [ -n "${DATABASE_CA_CERT_FILE:-}" ]; then
  echo "Using DATABASE_CA_CERT_FILE for TLS verification."
  export PGSSLROOTCERT="$DATABASE_CA_CERT_FILE"
  export PGSSLMODE="${PGSSLMODE:-verify-full}"
fi

pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="$backup_path" \
  "$DATABASE_URL"

echo "Backup completed: ${backup_path}"
