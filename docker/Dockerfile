# ./docker/Dockerfile
FROM debian:bookworm-slim

# Paquetes base
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates bash apache2 postgresql-client \
 && rm -rf /var/lib/apt/lists/*

# Instalar code-server (en Debian el install.sh funciona)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Copiar artefactos (SIN prefijo docker/ porque el contexto es ./docker)
COPY apache-hello-world/index.html /var/www/html/index.html
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Puertos: Apache 80, code-server 8080
EXPOSE 80 8080

# Apache se lanza desde entrypoint (junto a code-server)
CMD ["/usr/local/bin/entrypoint.sh"]
