# 랜덤 비밀번호 생성 (Aurora 마스터 계정용)
resource "random_password" "master_password" {
  length  = 16
  special = true
  override_special = "!#$%&()*+-.:;<=>?[]^_{|}~"  # '/' '@' '"' 공백 제외
}

# Secrets Manager (Aurora 접속 정보 저장용 Secret 생성)
resource "aws_secretsmanager_secret" "aurora" {
  name                    = "${var.cluster_identifier}-secret"
  recovery_window_in_days = 0 # 즉시 삭제 (보존기간 없음)
}

# Secret에 실제 비밀번호 및 접속 정보 저장 (Secret Version)
resource "aws_secretsmanager_secret_version" "aurora_version" {
  secret_id = aws_secretsmanager_secret.aurora.id
  secret_string = jsonencode({
    dbClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
    password            = random_password.master_password.result
    # 의미 분리: 엔진/모드/버전 각각 저장
    engine              = aws_rds_cluster.aurora.engine            # "aurora-postgresql"
    engine_mode         = aws_rds_cluster.aurora.engine_mode       # "provisioned"
    engine_version      = aws_rds_cluster.aurora.engine_version
    port                = 5432
    host                = aws_rds_cluster.aurora.endpoint
    username            = aws_rds_cluster.aurora.master_username
    db                  = aws_rds_cluster.aurora.database_name
  })
}

# Aurora용 서브넷 그룹 생성 (프라이빗 서브넷 연결)
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.cluster_identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.cluster_identifier}-subnet-group"
  }
}

# Aurora 접근을 위한 Security Group 생성 (5432 포트 허용)
resource "aws_security_group" "aurora" {
  name        = "${var.cluster_identifier}-sg"
  description = "Aurora access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks # 내부 통신 허용 범위 (10.0.0.0/16)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_identifier}-sg"
  }
}

# Aurora Serverless v2 클러스터 생성
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = var.cluster_identifier
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = var.engine_version
  database_name           = var.database_name
  master_username         = var.master_username
  master_password         = random_password.master_password.result
  enable_http_endpoint    = true
  skip_final_snapshot     = true
  apply_immediately       = true

  allow_major_version_upgrade = true

  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }

  vpc_security_group_ids = [aws_security_group.aurora.id]
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
}

# Aurora 클러스터 인스턴스 생성 (Serverless 타입)
resource "aws_rds_cluster_instance" "aurora_instance" {
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
}
