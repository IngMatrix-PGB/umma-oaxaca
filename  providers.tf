
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Org       = var.org
      Env       = var.env
      Org       = "micro-talent"
      ManagedBy = "Terraform"
    }
  }
}