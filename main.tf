# AWS User Group Oaxaca - PoC Demo
# Infrastructure as Code con Terraform
# Autor: Pablo Galeana

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configuración del proveedor AWS
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags_common
  }
}

# Módulo principal de micro-talent
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

# Outputs para el deployment
output "ec2_public_ip" {
  description = "IP pública de la instancia EC2"
  value       = module.micro_talent.ec2_public_ip
}

output "ec2_instance_id" {
  description = "ID de la instancia EC2"
  value       = module.micro_talent.ec2_instance_id
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos RDS"
  value       = module.micro_talent.rds_endpoint
  sensitive   = true
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR"
  value       = module.micro_talent.ecr_repository_url
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = module.micro_talent.vpc_id
}

output "application_url" {
  description = "URL de la aplicación web"
  value       = "http://${module.micro_talent.ec2_public_ip}"
}

output "code_server_url" {
  description = "URL del code-server"
  value       = "http://${module.micro_talent.ec2_public_ip}:8080"
}
