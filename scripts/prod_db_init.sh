#!/bin/sh

set -eu

if ! command -v mix >/dev/null 2>&1; then
  echo "mix is required but was not found in PATH" >&2
  exit 1
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

for required_var in SECRET_KEY_BASE WATER_BASIC_AUTH_USERNAMES WATER_BASIC_AUTH_PASSWORD; do
  eval "value=\${$required_var:-}"

  if [ -z "$value" ]; then
    echo "$required_var is required" >&2
    exit 1
  fi
done

if [ -n "${DATABASE_CA_CERT_FILE:-}" ]; then
  echo "Using DATABASE_CA_CERT_FILE for TLS verification."
fi

echo "Running migrations."
env MIX_ENV=prod DATABASE_URL="$DATABASE_URL" mix ecto.migrate

echo "Running seeds."
env MIX_ENV=prod DATABASE_URL="$DATABASE_URL" mix run priv/repo/seeds.exs
