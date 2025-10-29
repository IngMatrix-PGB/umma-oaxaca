module "micro_talent" {
  source = "./modules/micro-talent"

  # Configuración básica
  region      = var.region
  environment = var.environment
  name_prefix = var.name_prefix
  project     = var.project

  # Configuración de red
  vpc_cidr          = var.vpc_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs

  # Configuración de base de datos
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # Configuración de aplicación
  code_server_password = var.code_server_password
  instance_type        = var.instance_type

  # Docker image - usar latest del ECR
  docker_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.project}-app:latest"

  # Tags comunes
  tags_common = var.tags_common
}

# Data sources
data "aws_caller_identity" "current" {}
