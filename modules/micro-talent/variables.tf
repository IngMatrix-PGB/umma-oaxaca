variable "region" {
  type = string
}

variable "vpc_name" {
  type    = string
  default = "overflow-mt-vpc"
}

variable "vpc_cidr" {
  type = string
}

variable "allowed_ssh_cidrs" {
  type = list(string)
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "code_server_password" {
  type      = string
  sensitive = true
}

variable "project" {
  type = string
}
variable "environment" {
  type = string
}
variable "name_prefix" {
  type = string
}

variable "tags_common" {
  type = map(string)
}

variable "docker_image" {
  type = string
}