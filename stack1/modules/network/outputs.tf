# VPC ID 출력
output "vpc_id" {
  value       = aws_vpc.chatbot_vpc.id
  description = "생성된 VPC의 ID"
}

# 퍼블릭 서브넷 ID 목록 출력
output "public_subnet_ids" {
  value       = aws_subnet.chatbot_public[*].id
  description = "생성된 퍼블릭 서브넷 ID 목록"
}

# 프라이빗 서브넷 ID 목록 출력
output "private_subnet_ids" {
  value       = aws_subnet.chatbot_private[*].id
  description = "생성된 프라이빗 서브넷 ID 목록"
}
