#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/seed.sql"

# Connect via docker-compose postgres container
DB_CONTAINER="hapa_postgres"
DB_USER="hapa"
DB_NAME="hapa"

echo "🌱 Seeding Hapa database..."

if docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
  docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$SQL_FILE"
else
  # fallback: direct psql if postgres is running locally on remapped port 5433
  PGPASSWORD="${POSTGRES_PASSWORD:-hapapass}" psql \
    -h localhost -p 5433 -U "$DB_USER" -d "$DB_NAME" < "$SQL_FILE"
fi

echo "✅ Seed complete!"
echo "   20 users | 15 businesses | 110+ posts"
