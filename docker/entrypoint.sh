#!/usr/bin/env bash
set -euo pipefail

: "${CODE_SERVER_PASSWORD:=changeme}"
: "${DB_HOST:=}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=}"
: "${DB_USER:=}"
: "${DB_PASSWORD:=}"

export HOME=/root

# Función para logging con timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log " Iniciando servicios para AWS User Group Oaxaca PoC..."

# Iniciar Apache HTTP Server
log " Iniciando Apache HTTP Server..."
httpd -D FOREGROUND &
APACHE_PID=$!

# Configuración de code-server
log "💻 Configurando code-server..."
mkdir -p /root/.config/code-server /root/.local/share/code-server
cat >/root/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${CODE_SERVER_PASSWORD}
cert: false
disable-telemetry: true
disable-update-check: true
EOF

# Iniciar code-server en background
log "🔧 Iniciando code-server..."
(
  while true; do
    log "[code-server] Iniciando..."
    code-server --user-data-dir /root/.local/share/code-server --disable-telemetry
    rc=$?
    log "[code-server] Terminó con código ${rc}, reintentando en 2s..."
    sleep 2
  done
) >>/var/log/code-server.log 2>&1 &
CODE_SERVER_PID=$!

# Chequeo opcional de RDS
if [[ -n "$DB_HOST" && -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]]; then
  log "🗄️ Probando conexión a RDS: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
  if PGPASSWORD="$DB_PASSWORD" \
     psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "select version();" \
     >/var/log/rds-check.log 2>&1; then
    log " Conexión a PostgreSQL exitosa"
  else
    log " No se pudo conectar a RDS. Ver /var/log/rds-check.log"
  fi
fi

log " Servicios iniciados correctamente!"
log " Apache HTTP Server: puerto 80"
log " Code Server: puerto 8080"
log "Password code-server: ${CODE_SERVER_PASSWORD}"

# Función de limpieza al salir
cleanup() {
    log " Deteniendo servicios..."
    kill $APACHE_PID $CODE_SERVER_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Mantener el contenedor corriendo y mostrar logs
log " Monitoreando logs..."
tail -F /var/log/code-server.log /var/log/rds-check.log 2>/dev/null &
wait
