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

# Aurora Serverless v2 - PostgreSQL 16
# min_capacity=0 enables scale-to-zero (free when idle).
resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${local.name_prefix}-aurora"
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned"
  engine_version         = "16.6"
  database_name          = var.db_name
  master_username        = var.db_username
  master_password        = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]

  storage_encrypted   = true
  skip_final_snapshot = true
  deletion_protection = false

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  tags = {
    Name    = "${local.name_prefix}-aurora"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_rds_cluster_instance" "main" {
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  db_subnet_group_name = aws_db_subnet_group.main.name

  tags = {
    Name    = "${local.name_prefix}-aurora-instance"
    Project = var.project
    Env     = var.env
  }
}
