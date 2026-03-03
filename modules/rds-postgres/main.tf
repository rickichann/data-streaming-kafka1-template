locals {
  common_tags = merge(var.tags, {
    Project = var.project_name
    Managed = "terraform"
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.common_tags, { Name = "${var.project_name}-db-subnet-group" })
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "RDS PostgreSQL SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from allowed SGs"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_sg_ids
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-sg-rds" })
}

resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true

  auto_minor_version_upgrade = true
  parameter_group_name = aws_db_parameter_group.postgres.name

  tags = merge(local.common_tags, { Name = "${var.project_name}-postgres" })
}

# custom parameter group
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.project_name}-pg-params"
  family = var.db_parameter_group_family 

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_replication_slots"
    value        = "10"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_wal_senders"
    value        = "10"
    apply_method = "pending-reboot"
  }

  tags = var.tags
}