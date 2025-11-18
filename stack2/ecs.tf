# Remote values from stack1 (VPC/ALB/TG)
locals {
  vpc_id               = data.terraform_remote_state.stack1.outputs.vpc_id
  private_subnet_ids   = data.terraform_remote_state.stack1.outputs.private_subnet_ids
  alb_sg_id            = data.terraform_remote_state.stack1.outputs.alb_sg_id
  ecs_target_group_arn = data.terraform_remote_state.stack1.outputs.ecs_target_group_arn

  # 운영 앱 로그 그룹 이름 (stack1이 생성/관리)
  log_group_name = var.chatbot_log_group_name
}

# Context for IAM/SSM
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# stack1이 먼저 생성, stack2 오직 "읽기"
data "aws_cloudwatch_log_group" "app" {
  name = local.log_group_name
}

# SSM 파라미터 ARN (/chatbot/bedrock/kb_id: ap-northeast-2)
locals {
  kb_id_param_arn = "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter${var.kb_id_ssm_parameter_name}"
}

# us-east-1 Guardrail Param ARN
locals {
  guardrail_param_prefix_arn = "arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter${var.guardrail_ssm_prefix}*"
}

# KB 파라미터(ap-northeast-2) + Guardrail 파라미터(us-east-1 프리픽스)
resource "aws_iam_policy" "task_ssm_read" {
  name        = "chat-ecs-task-ssm-read"
  description = "Allow ECS task to read KB ID & Guardrail params"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "GetParams",
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        Resource = [
          local.kb_id_param_arn,
          local.guardrail_param_prefix_arn
        ]
      }
      # Guardrail 파라미터가 SecureString + 고객 관리형 CMK이면 아래 kms:Decrypt와 키정책 허용도 필요
      # ,{
      #   "Sid": "AllowKmsDecryptGuardrail",
      #   "Effect": "Allow",
      #   "Action": ["kms:Decrypt"],
      #   "Resource": "<us-east-1의 해당 KMS Key ARN>"
      # }
    ]
  })
}

# 추가: ECS Task Role용 Bedrock/RAG 권한 (멀티 리전)
resource "aws_iam_policy" "task_bedrock_permissions" {
  name        = "chat-ecs-task-bedrock"
  description = "Allow ECS task to access Bedrock (KB Retrieve, Nova Pro, Rerank, Guardrail)"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # KB 검색 (ap-northeast-2)
      {
        Sid    = "AllowRetrieveKB",
        Effect = "Allow",
        Action = ["bedrock:Retrieve"],
        Resource = "*"
      },

      # Nova Pro 호출 (us-east-1)
      {
        Sid    = "AllowInvokeNovaPro",
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ],
        Resource = "*"
      },

      # Rerank (ap-northeast-1)
      {
        Sid    = "AllowRerank",
        Effect = "Allow",
        Action = [
          "bedrock:Rerank",
          "bedrock:InvokeModel"
        ],
        Resource = "*"
      },

      # Guardrail (us-east-1)
      {
        Sid    = "AllowApplyGuardrail",
        Effect = "Allow",
        Action = "bedrock:ApplyGuardrail",
        Resource = "*"
      }
    ]
  })
}

# 조건부 ECS 서비스 생성 로직
locals {
  # 이미지가 있고 desired_count > 0일 때만 ECS 서비스 생성
  create_ecs_service = var.chatbot_image != "" && var.desired_count > 0
}

# ECS Cluster (Fargate) - 항상 생성
module "ecs_cluster" {
  source = "terraform-aws-modules/ecs/aws//modules/cluster"
  # version = "~> 6.0"

  name = "chat-ecs"

  default_capacity_provider_strategy = {
    FARGATE      = { weight = 50, base = 1 }
    FARGATE_SPOT = { weight = 50 }
  }

  # 클러스터 기본 로그 그룹 자동생성 방지
  create_cloudwatch_log_group = false

  tags = { Project = "chatbot" }
}

# ECS Service (컨테이너 앱 :8501)
# 서비스용 보안그룹 (ALB → 8501 허용)
resource "aws_security_group" "ecs_service_sg" {
  name        = "chat-ecs-service-sg"
  description = "Allow ALB to ECS service 8501"
  vpc_id      = local.vpc_id

  # egress 전체 허용 (필요 시 도메인/포트 제한으로 강화 가능)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "chat-ecs-service-sg" }
}

resource "aws_security_group_rule" "alb_to_ecs_8501" {
  type                     = "ingress"
  from_port                = 8501
  to_port                  = 8501
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_service_sg.id
  source_security_group_id = local.alb_sg_id
  description              = "ALB to ECS 8501"
}

# ECS Service - 조건부 생성
module "ecs_service" {
  count = local.create_ecs_service ? 1 : 0
  
  source = "terraform-aws-modules/ecs/aws//modules/service"
  # version = "~> 6.0"

  name                   = "chat-app"
  cluster_arn            = module.ecs_cluster.arn
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  desired_count          = var.desired_count
  enable_execute_command = true
  force_delete           = true # 서비스 삭제 시 태스크 강제 종료

  # 네트워킹
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.ecs_service_sg.id]
  assign_public_ip   = false

  # 태스크 리소스
  cpu    = 1024
  memory = 2048

  # IAM 설정
  create_task_exec_iam_role = true # Execution Role 자동 생성
  tasks_iam_role_name       = "chat-ecs-task"
  tasks_iam_role_policies = {
    ssm_read            = aws_iam_policy.task_ssm_read.arn
    bedrock_permissions = aws_iam_policy.task_bedrock_permissions.arn
  }

  # Execution Role에서 SSM 파라미터/Secrets를 읽게 할 필요가 있으면 ARN 추가
  task_exec_ssm_param_arns = [aws_ssm_parameter.kb_id_param.arn]

  # ALB Target Group (ip 타입)과 매핑
  load_balancer = {
    service = {
      target_group_arn = local.ecs_target_group_arn
      container_name   = "app"
      container_port   = 8501
    }
  }

  # 컨테이너 정의
  container_definitions = {
    app = {
      essential = true
      image     = var.chatbot_image

      portMappings = [{
        name          = "app"
        containerPort = 8501
        hostPort      = 8501
        protocol      = "tcp"
      }]

      # CloudWatch Logs - stack1이 만든 그룹만 사용 (여기서 생성하지 않음)
      enable_cloudwatch_logging   = true
      create_cloudwatch_log_group = false
      cloudwatch_log_group_name   = local.log_group_name

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.log_group_name
          awslogs-region        = "ap-northeast-2"
          awslogs-stream-prefix = "ecs"
        }
      }

      # (선택) 컨테이너 내부 헬스체크
      # healthCheck = {
      #   command     = ["CMD-SHELL", "curl -f http://localhost:8501/_stcore/health || exit 1"]
      #   interval    = 30
      #   timeout     = 5
      #   retries     = 3
      #   startPeriod = 10
      # }

      readonlyRootFilesystem = false
    }
  }

  tags = { Project = "chatbot" }
}
