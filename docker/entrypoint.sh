#!/usr/bin/env bash
set -euo pipefail

: "${CODE_SERVER_PASSWORD:=changeme}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-}"
DB_USER="${DB_USER:-}"
DB_PASSWORD="${DB_PASSWORD:-}"

export HOME=/root

service apache2 start

mkdir -p /root/.local/share/code-server
(
  while true; do
    echo "[code-server] starting..."
    code-server \
      --bind-addr 0.0.0.0:8080 \
      --auth password \
      --password "${CODE_SERVER_PASSWORD}" \
      --user-data-dir /root/.local/share/code-server \
      --disable-telemetry
    echo "[code-server] exited ($?), retrying in 2s..."
    sleep 2
  done
) >>/var/log/code-server.log 2>&1 &

# Chequeo opcional a RDS
if [[ -n "$DB_HOST" && -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]]; then
  echo "[rds-check] Probar conexión a ${DB_HOST}:${DB_PORT}/${DB_NAME}"
  if PGPASSWORD="$DB_PASSWORD" \
     psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "select version();" \
     >/var/log/rds-check.log 2>&1; then
    echo "[rds-check] OK: conexión a Postgres exitosa"
  else
    echo "[rds-check] WARNING: no se pudo conectar. Ver /var/log/rds-check.log"
  fi
fi

echo "Apache :80  |  code-server :8080"
tail -F /var/log/apache2/access.log /var/log/apache2/error.log /var/log/code-server.log /var/log/rds-check.log 2>/dev/null