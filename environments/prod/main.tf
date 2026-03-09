module "network" {
  source = "../../modules/network"

  aws_region           = var.aws_region
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = { Env = "prod" }
}




# This is your compute/app SG placeholder in prod.
# Later attach it to EC2/ECS/Lambda-in-VPC so it can reach RDS.
resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg-app"
  description = "App SG that is allowed to reach RDS"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-app"
    Env  = "prod"
  }
}

module "rds" {
  source = "../../modules/rds-postgres"

  project_name       = var.project_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  allowed_sg_ids = [
    aws_security_group.app.id,
    module.bastion.bastion_sg_id,
    module.data_cluster.security_group_id
  ]

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  db_parameter_group_family = var.db_family 

  tags = {
    Env = "prod"
  }
}

module "data_cluster" {
  source = "../../modules/ec2-cluster"

  project_name       = var.project_name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  instance_type = "t3.medium"
  bastion_sg_id = module.bastion.bastion_sg_id

  tags = {
    Env = "prod"
  }
}

module "s3tables" {
  source = "../../modules/s3tables-buckets"

  project_name = var.project_name

  table_bucket_names = [
    "dbstream2026-bronze",
    "dbstream2026-silver",
  ]

  # optional (can remove if you don't want namespaces now)
  namespaces = ["bronze", "silver"]

  tags = {
    Env = "prod"
  }
}

module "lambda_customer" {
  source = "../../modules/lambda-private"

  lambda_name = "da2026-lambda-customer"

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  source_dir = "${path.root}/../../modules/lambda-private/customer"

  environment_variables = {
    JOB = "customer"
  }

  tags = {
    Env = "prod"
  }
}

module "lambda_transaction" {
  source = "../../modules/lambda-private"

  lambda_name = "da2026-lambda-transaction"

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  source_dir = "${path.root}/../../modules/lambda-private/transaction"

  environment_variables = {
    JOB = "transaction"
  }

  tags = {
    Env = "prod"
  }
}

module "bastion" {
  source = "../../modules/ec2-bastion"

  project_name     = var.project_name
  vpc_id           = module.network.vpc_id
  public_subnet_id = try(module.network.public_subnet_ids[0],null)

  allowed_ssh_cidr = "103.94.10.189/32"
  key_name         = "datastreaming020326-ec2-keypair-name"

  tags = {
    Env = "prod"
  }
}



