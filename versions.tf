terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    random  = { source = "hashicorp/random", version = ">= 2.0.0" }
    archive = { source = "hashicorp/archive", version = ">= 2.0.0" }
  }
  backend "s3" {
    encrypt = true
    acl     = "bucket-owner-full-control"
  }
}