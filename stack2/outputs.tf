# Bedrock Knowledge Base 리소스 ID/ARN 출력 (이 값은 EC2 환경변수 또는 다른 모듈에서 참조 가능)
output "bedrock_knowledge_base_id" {
  value = module.bedrock_kb.knowledge_base_id
}

output "bedrock_knowledge_base_arn" {
  value = module.bedrock_kb.knowledge_base_arn
}

# ECS 관련 출력
output "ecs_cluster_arn" {
  value = module.ecs_cluster.arn
}

output "ecs_service_name" {
  value = length(module.ecs_service) > 0 ? module.ecs_service[0].name : ""
  description = "ECS 서비스 이름 (서비스가 생성되지 않았으면 빈 문자열)"
}

output "ecs_service_security_group_id" {
  value = aws_security_group.ecs_service_sg.id
}

