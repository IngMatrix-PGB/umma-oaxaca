variable "region" { type = string }
variable "project" { type = string }
variable "db_name" { type = string }
variable "db_username" {
  type      = string
  sensitive = true
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "vpc_cidr" { type = string }
variable "allowed_ssh_cidrs" { type = list(string) }
variable "code_server_password" {
  type      = string
  sensitive = true
}
variable "environment" { type = string }
variable "name_prefix" { type = string }
variable "tags_common" { type = map(string) }
variable "docker_image" {
  description = "URI completo de la imagen (registry/repo:tag). Si es null, se usa una imagen de prueba."
  type        = string
  default     = null
}

variable "instance_type" { type = string }
