# Aurora 클러스터 관련 출력
output "db_endpoint" {
  value = module.aurora.cluster_endpoint
}

output "db_reader_endpoint" {
  value = module.aurora.cluster_reader_endpoint
}

output "aurora_arn" {
  value = module.aurora.database_arn
}

output "aurora_secret_arn" {
  value = module.aurora.database_secretsmanager_secret_arn
}

# 네트워크 구성 출력
output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

# S3 버킷 정보 출력
output "s3_bucket_name" {
  value = module.s3.bucket_name
}

output "s3_bucket_arn" {
  value = module.s3.arn
}

# ALB 관련 출력
output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "alb_sg_id" {
  value = module.security.alb_sg_id
}

output "ecs_target_group_arn" {
  value = module.alb.ecs_target_group_arn
}
