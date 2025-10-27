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
  systemctl enable --now docker

  # Deriva el registry a partir de la imagen completa que viene de TF
  REGISTRY_DOMAIN=$(echo ${var.docker_image} | cut -d'/' -f1)

  # OJO: usar $$ para que Terraform NO interpole, y lo haga bash en runtime
  aws ecr get-login-password --region ${var.region} \
    | docker login --username AWS --password-stdin $${REGISTRY_DOMAIN}

  docker pull "${var.docker_image}" || true
  docker rm -f overflow || true

  docker run -d --name overflow --restart unless-stopped \
    -p 80:80 -p 8080:8080 \
    -e CODE_SERVER_PASSWORD='${var.code_server_password}' \
    -e DB_HOST='${module.rds.db_instance_address}' \
    -e DB_PORT='5432' \
    -e DB_NAME='${var.db_name}' \
    -e DB_USER='${var.db_username}' \
    -e DB_PASSWORD='${var.db_password}' \
    "${var.docker_image}"
EOT
  )
}
