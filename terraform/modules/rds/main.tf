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

# Aurora Serverless v1 - PostgreSQL 13
# Costs only when active (~$0.06/ACU-hour); auto-pauses when idle.
resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${local.name_prefix}-aurora"
  engine                 = "aurora-postgresql"
  engine_mode            = "serverless"
  engine_version         = "13.9"
  database_name          = var.db_name
  master_username        = var.db_username
  master_password        = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]

  storage_encrypted    = true
  skip_final_snapshot  = true
  deletion_protection  = false

  enable_http_endpoint = false

  scaling_configuration {
    auto_pause               = var.auto_pause
    min_capacity             = var.min_capacity
    max_capacity             = var.max_capacity
    seconds_until_auto_pause = var.seconds_until_auto_pause
    timeout_action           = "ForceApplyCapacityChange"
  }

  tags = {
    Name    = "${local.name_prefix}-aurora"
    Project = var.project
    Env     = var.env
  }
}
