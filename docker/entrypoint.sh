#!/usr/bin/env bash
set -euo pipefail

# --------- Config ---------
: "${CODE_SERVER_PASSWORD:=changeme}"
: "${DB_HOST:=}"
: "${DB_PORT:=5432}"
: "${DB_NAME:=}"
: "${DB_USER:=}"
: "${DB_PASSWORD:=}"

export HOME=/root

# --------- Utils ---------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Archivos de log (crearlos antes de tail)
mkdir -p /var/log
touch /var/log/code-server.log /var/log/rds-check.log

log "🚀 Iniciando servicios para AWS User Group Oaxaca PoC..."

# --------- Apache start (Alpine/Debian portable) ---------
start_apache() {
  if command -v httpd-foreground >/dev/null 2>&1; then
    # Imagen httpd Alpine
    log "🌐 Iniciando Apache (Alpine)..."
    httpd-foreground &
    echo $! > /var/run/apache.pid
  elif command -v apache2ctl >/dev/null 2>&1; then
    # Debian/Ubuntu
    log "🌐 Iniciando Apache (Debian)..."
    apache2ctl -D FOREGROUND &
    echo $! > /var/run/apache.pid
  elif command -v httpd >/dev/null 2>&1; then
    log "🌐 Iniciando Apache (httpd)..."
    httpd -D FOREGROUND &
    echo $! > /var/run/apache.pid
  else
    log "❌ No se encontró comando para iniciar Apache."
    exit 1
  fi
}

# --------- code-server config ---------
setup_code_server() {
  log "💻 Configurando code-server..."
  mkdir -p /root/.config/code-server /root/.local/share/code-server /workspace

  cat >/root/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${CODE_SERVER_PASSWORD}
cert: false
disable-telemetry: true
disable-update-check: true
EOF
}

start_code_server() {
  log "🔧 Iniciando code-server con auto-reintentos..."
  (
    delay=2
    while true; do
      log "[code-server] start (delay=${delay}s si cae)"
      # Nota: --user-data-dir para aislar datos y logs
      if code-server --user-data-dir /root/.local/share/code-server /workspace >>/var/log/code-server.log 2>&1; then
        rc=0
      else
        rc=$?
      fi
      log "[code-server] terminó con código ${rc}"
      sleep "$delay"
      # backoff hasta 10s
      if (( delay < 10 )); then delay=$((delay+1)); fi
    done
  ) &
  echo $! > /var/run/code-server.pid
}

# --------- Optional RDS check ---------
check_rds() {
  if [[ -n "$DB_HOST" && -n "$DB_NAME" && -n "$DB_USER" && -n "$DB_PASSWORD" ]]; then
    log "🗄️ Probando conexión a RDS: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    if PGPASSWORD="$DB_PASSWORD" \
       psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "select version();" \
       >/var/log/rds-check.log 2>&1; then
      log "✅ Conexión a PostgreSQL exitosa"
    else
      log "⚠️ No se pudo conectar a RDS. Revisa /var/log/rds-check.log"
    fi
  fi
}

# --------- Start all ---------
start_apache
setup_code_server
start_code_server
check_rds

APACHE_PID="$(cat /var/run/apache.pid)"
CODE_SERVER_PID="$(cat /var/run/code-server.pid)"

log "✅ Servicios iniciados correctamente"
log "   • Apache: puerto 80"
log "   • code-server: puerto 8080"
log "   • Password code-server: ${CODE_SERVER_PASSWORD}"

# --------- Cleanup ---------
cleanup() {
  log "🧹 Deteniendo servicios..."
  # Intentar apagar con gracia
  if [[ -n "${APACHE_PID:-}" ]] && kill -0 "$APACHE_PID" 2>/dev/null; then kill "$APACHE_PID" 2>/dev/null || true; fi
  if [[ -n "${CODE_SERVER_PID:-}" ]] && kill -0 "$CODE_SERVER_PID" 2>/dev/null; then kill "$CODE_SERVER_PID" 2>/dev/null || true; fi
  exit 0
}
trap cleanup SIGTERM SIGINT

# --------- Log follow (portable) ---------
# BusyBox tail (Alpine) no soporta -F; usamos -f. Como ya hicimos 'touch', no se cae.
log "📜 Monitoreando logs..."
tail -n +1 -f /var/log/code-server.log /var/log/rds-check.log &
TAIL_PID=$!

# Esperar a cualquiera
wait -n "$APACHE_PID" "$CODE_SERVER_PID" "$TAIL_PID"
