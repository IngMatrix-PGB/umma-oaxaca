module "micro_talent" {
  source = "./modules/micro-talent"

  # --- identidad/red ---
  project           = var.project
  name_prefix       = var.name_prefix
  environment       = var.environment
  region            = var.region
  vpc_cidr          = var.vpc_cidr
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  instance_type     = var.instance_type

  # --- base de datos ---
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # --- app ---
  code_server_password = var.code_server_password
  docker_image         = var.docker_image

  tags_common = var.tags_common
}