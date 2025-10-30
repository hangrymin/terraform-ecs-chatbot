# ALB 생성 (퍼블릭 접근용)
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
}

# === ECS(Fargate) 전용 Target Group (IP 타입) ===
resource "aws_lb_target_group" "tg_ecs" {
  name        = "${var.name_prefix}-tg-ecs"
  port        = 8501
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/_stcore/health"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }
}

# ALB 리스너 (HTTP 80 → ECS용 Target Group 포워딩)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_ecs.arn
  }
}
