# Imagen base más ligera para PoC
FROM httpd:2.4-alpine

# Instalar dependencias mínimas necesarias
RUN apk add --no-cache \
    bash \
    curl \
    postgresql-client \
    && rm -rf /var/cache/apk/*

# Instalar code-server para la demo
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Copiar archivos de la aplicación
COPY apache-hello-world/index.html /usr/local/apache2/htdocs/index.html
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Configurar Apache para mostrar archivos estáticos
RUN echo "LoadModule rewrite_module modules/mod_rewrite.so" >> /usr/local/apache2/conf/httpd.conf

EXPOSE 80 8080
CMD ["/usr/local/bin/entrypoint.sh"]