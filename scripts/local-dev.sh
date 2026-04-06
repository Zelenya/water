#!/bin/sh
set -eu

echo "Fetching Mix dependencies..."
mix deps.get

echo "Waiting for Postgres at ${DATABASE_HOST:-db}:${DATABASE_PORT:-5432}..."
until pg_isready \
  -h "${DATABASE_HOST:-db}" \
  -p "${DATABASE_PORT:-5432}" \
  -U "${DATABASE_USER:-postgres}" \
  -d "${DATABASE_NAME:-water_dev}" \
  >/dev/null 2>&1; do
  sleep 1
done

echo "Creating database if needed..."
mix ecto.create

echo "Running migrations..."
mix ecto.migrate

echo "Seeding demo data..."
mix run priv/repo/seeds.exs

exec mix phx.server
