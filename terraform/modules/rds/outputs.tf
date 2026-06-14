output "db_endpoint" {
  value = aws_rds_cluster.main.endpoint
}

output "db_host" {
  value = aws_rds_cluster.main.endpoint
}

output "db_port" {
  value = aws_rds_cluster.main.port
}

output "db_name" {
  value = aws_rds_cluster.main.database_name
}

output "db_username" {
  value = aws_rds_cluster.main.master_username
}

output "cluster_id" {
  value = aws_rds_cluster.main.cluster_identifier
}
