locals {
  name_prefix = "${var.project}-${var.env}"
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name    = "${local.name_prefix}-db-subnet-group"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_db_parameter_group" "main" {
  name   = "${local.name_prefix}-pg14"
  family = "postgres14"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = {
    Name    = "${local.name_prefix}-pg14"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-db"

  engine         = "postgres"
  engine_version = "14"
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az               = var.multi_az
  publicly_accessible    = false
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.name_prefix}-final-snapshot" : null

  backup_retention_period = var.env == "prd" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = {
    Name    = "${local.name_prefix}-db"
    Project = var.project
    Env     = var.env
  }
}
