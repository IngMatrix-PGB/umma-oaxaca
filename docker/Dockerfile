# Imagen base Debian para evitar problemas con el instalador de code-server
FROM debian:bookworm-slim

# Paquetes base
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates bash apache2 \
 && rm -rf /var/lib/apt/lists/*

# Instalar code-server con el instalador oficial (aquí sí funciona)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Archivos de tu app
COPY docker/apache-hello-world/index.html /var/www/html/index.html
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Exponer puertos: Apache (80) y code-server (8080)
EXPOSE 80 8080

# En Debian, Apache en foreground con apache2ctl
CMD ["/usr/local/bin/entrypoint.sh"]
