# Aurora Writer 엔드포인트
output "cluster_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

# Aurora Reader 엔드포인트
output "cluster_reader_endpoint" {
  value = aws_rds_cluster.aurora.reader_endpoint
}

# Aurora 클러스터 ID
output "cluster_id" {
  value = aws_rds_cluster.aurora.id
}

# 마스터 비밀번호 (보안 주의 필요)
output "master_password" {
  value = aws_rds_cluster.aurora.master_password
}

# 데이터베이스 이름
output "database_name" {
  value = aws_rds_cluster.aurora.database_name
}

# Aurora 클러스터 ARN
output "database_arn" {
  value = aws_rds_cluster.aurora.arn
}

# Secrets Manager ARN
output "database_secretsmanager_secret_arn" {
  value = aws_secretsmanager_secret_version.aurora_version.arn
}

# 마스터 사용자 이름
output "database_master_username" {
  value = aws_rds_cluster.aurora.master_username
}
