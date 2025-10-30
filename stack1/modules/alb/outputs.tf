# ALB의 DNS 이름 출력
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

# ECS용 Target Group ARN 출력 (새로 추가)
output "ecs_target_group_arn" {
  value = aws_lb_target_group.tg_ecs.arn
}