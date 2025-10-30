# ALB용 보안 그룹 ID 출력
output "alb_sg_id" {
  value = aws_security_group.alb.id
}
