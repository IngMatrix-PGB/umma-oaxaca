module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.9"

  name               = "${local.base_name}-vpc"
  cidr               = var.vpc_cidr
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets     = local.public_subnets
  private_subnets    = local.private_subnets
  enable_flow_log    = false
  enable_nat_gateway = true
  single_nat_gateway = true
}
module "ec2_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.base_name}-ec2-sg"
  description = "SSH/HTTP/CodeServer access"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = concat(
    [
      { rule = "http-80-tcp", description = "HTTP public", cidr_blocks = "0.0.0.0/0" },

      { from_port = 8080, to_port = 8080, protocol = "tcp",
      description = "code-server public", cidr_blocks = "0.0.0.0/0" }
    ],
    [for c in var.allowed_ssh_cidrs : {
      rule        = "ssh-tcp"
      description = "SSH restricted"
      cidr_blocks = c
    }]
  )

  egress_rules = ["all-all"]
}

module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.base_name}-rds-sg"
  description = "Postgres from EC2 only"
  vpc_id      = module.vpc.vpc_id
  ingress_with_source_security_group_id = [{
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    description              = "Postgres from EC2"
    source_security_group_id = module.ec2_sg.security_group_id
  }]
  egress_rules = ["all-all"]
}

module "iam_ec2_overflow" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.34"

  create_role           = true
  role_requires_mfa     = false
  role_name             = "${local.base_name}-ec2-role"
  role_description      = "IAM role for EC2 to pull from ECR and use SSM"
  trusted_role_services = ["ec2.amazonaws.com"]
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_readonly" {
  role       = module.iam_ec2_overflow.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = module.iam_ec2_overflow.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile_overflow" {
  name = "${local.base_name}-ec2-profile"
  role = module.iam_ec2_overflow.iam_role_name
}

data "aws_ssm_parameter" "al2023_x86" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

locals {
  ec2_ami = data.aws_ssm_parameter.al2023_x86.value
}

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name                        = "${local.base_name}-ec2"
  ami                         = local.ec2_ami
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.ec2_sg.security_group_id]
  user_data_base64            = local.user_data
  user_data_replace_on_change = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile_overflow.name
  enable_volume_tags          = true

  #  Garantiza que cloud-init pueda usar IMDS y ejecute user_data
    metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.0"

  repository_name               = "${var.project}-app"
  repository_image_scan_on_push = true
  repository_force_delete       = true
  create_lifecycle_policy       = true
  repository_lifecycle_policy   = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "keep last 10",
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 },
      action       = { type = "expire" }
    }]
  })
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier             = "${local.base_name}-pg"
  engine                 = "postgres"
  engine_version         = "16.3"
  family                 = "postgres16"
  major_engine_version   = "16"
  instance_class         = "db.t4g.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_encrypted      = true
  multi_az               = false
  publicly_accessible    = false
  vpc_security_group_ids = [module.rds_sg.security_group_id]
  subnet_ids             = module.vpc.private_subnets
  create_db_subnet_group = true
  skip_final_snapshot    = true
  deletion_protection    = false
}