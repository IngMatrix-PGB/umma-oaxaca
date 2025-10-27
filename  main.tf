module "micro_talent" {
  source = "./modules/micro-talent"

  region               = var.region
  vpc_cidr             = var.vpc_cidr
  allowed_ssh_cidrs    = var.allowed_ssh_cidrs
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  code_server_password = var.code_server_password

  project     = var.project
  environment = try(var.environment, null) != null ? var.environment : var.env
  name_prefix = var.name_prefix
  tags_common = var.tags_common

  docker_image = var.docker_image
}