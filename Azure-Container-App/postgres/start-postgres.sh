#!/bin/sh
set -eu

export PGDATA="${PGDATA:-/tmp/postgres-data}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
LATEST_BACKUP="$BACKUP_DIR/latest.sql"
INIT_DIR="/docker-entrypoint-initdb.d"

mkdir -p "$BACKUP_DIR" "$INIT_DIR"

if [ ! -s "$PGDATA/PG_VERSION" ] && [ -s "$LATEST_BACKUP" ]; then
  echo "Found persistent backup at $LATEST_BACKUP, preparing restore on first init."
  cp "$LATEST_BACKUP" "$INIT_DIR/001-restore.sql"
fi

docker-entrypoint.sh "$@" &
postgres_pid="$!"

until pg_isready -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Waiting for PostgreSQL before backup loop..."
  sleep 5
done

while kill -0 "$postgres_pid" 2>/dev/null; do
  if PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h 127.0.0.1 -U "$POSTGRES_USER" "$POSTGRES_DB" > "$BACKUP_DIR/latest.sql.tmp"; then
    mv "$BACKUP_DIR/latest.sql.tmp" "$LATEST_BACKUP"
    echo "Persistent backup updated at $LATEST_BACKUP"
  else
    echo "Persistent backup failed"
    rm -f "$BACKUP_DIR/latest.sql.tmp"
  fi

  sleep "${BACKUP_INTERVAL_SECONDS:-60}"
done

wait "$postgres_pid"
