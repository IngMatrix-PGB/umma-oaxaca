locals {
  env_short = (
    var.environment == "production" ? "prd" :
    var.environment == "staging" ? "stg" : "dev"
  )

  base_name = lower(join("-", compact([var.name_prefix, local.env_short, var.project])))

  default_tags = merge(var.tags_common, {
    Name        = local.base_name
    Environment = var.environment
    Project     = var.project
  })

  public_subnets = [
    cidrsubnet(var.vpc_cidr, 5, 0),
    cidrsubnet(var.vpc_cidr, 5, 1),
    cidrsubnet(var.vpc_cidr, 5, 2),
  ]

  private_subnets = [
    cidrsubnet(var.vpc_cidr, 5, 3),
    cidrsubnet(var.vpc_cidr, 5, 4),
    cidrsubnet(var.vpc_cidr, 5, 5),
  ]

    user_data = base64encode(<<-EOT
  #!/bin/bash
  set -euxo pipefail

  dnf -y update
  dnf -y install docker || curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker || true

  # Esperar a que Docker realmente esté arriba
  for i in {1..10}; do
    systemctl is-active --quiet docker && break || true
    echo "[docker] esperando servicio ($i/10)…"
    sleep 2
  done

  # Deriva el registry a partir de la imagen completa que viene de TF
  REGISTRY_DOMAIN=$(echo ${var.docker_image} | cut -d'/' -f1)

  # Login a ECR con reintentos (la instancia puede tardar en tener red/IMDS listo)
  for i in {1..6}; do
    if aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin $${REGISTRY_DOMAIN}; then
      echo "[ecr] login OK"
      break
    fi
    echo "[ecr] reintentando login ($i/6)…"
    sleep 5
  done

  # Pull con reintentos
  for i in {1..3}; do
    docker pull "${var.docker_image}" && break || {
      echo "[docker] retry pull ($i/3)…"
      sleep 3
    }
  done

  # Idempotencia del contenedor
  docker rm -f overflow 2>/dev/null || true

  # Arrancar contenedor app (Apache :80 y code-server :8080)
  docker run -d --name overflow --restart unless-stopped \
    -p 80:80 -p 8080:8080 \
    -e CODE_SERVER_PASSWORD='${var.code_server_password}' \
    -e DB_HOST='${module.rds.db_instance_address}' \
    -e DB_PORT='5432' \
    -e DB_NAME='${var.db_name}' \
    -e DB_USER='${var.db_username}' \
    -e DB_PASSWORD='${var.db_password}' \
    "${var.docker_image}"

  # Healthcheck simple: esperar hasta 2 min a que Apache conteste localmente
  for i in {1..24}; do
    if curl -sS --max-time 2 http://127.0.0.1/ >/dev/null; then
      echo "[health] Apache OK"
      break
    fi
    echo "[health] esperando Apache ($i/24)…"
    sleep 5
  done

  echo "[done] bootstrap completado"
EOT
  )
}
