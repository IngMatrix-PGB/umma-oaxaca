########################################################
# AWS COMMON VARIABLES
########################################################
region   = "us-east-1"
project  = "overflow"
vpc_cidr = "10.64.0.0/20"

allowed_ssh_cidrs = ["0.0.0.0/0"]

db_name              = "appdb"
db_username          = "postgres"
db_password          = "supersecreto"
code_server_password = "vscode-pass"

tags_common = {
  Project      = "overflow"
  Environment  = "development"
  Owner        = "Pablo Galeana Bailey"
  ManagedBy    = "Terraform"
  Repo         = "github.com/umma-oaxaca"
}
