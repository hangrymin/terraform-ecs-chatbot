data "aws_caller_identity" "current" {}

# Knowledge Base가 사용할 KMS 키
resource "aws_kms_key" "bedrock_kb_key" {
  description             = "KMS key for Bedrock Knowledge Base to decrypt S3 data"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
    Statement = [
      {
        Sid    = "AllowRootAccountFullAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      }
    ]
  })
}

# Bedrock Knowledge Base용 IAM Role
resource "aws_iam_role" "bedrock_kb_role" {
  name = "${var.knowledge_base_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })
}

# RDS Data API 접근 권한 정책
resource "aws_iam_policy" "rds_data_api_policy" {
  name = "${var.knowledge_base_name}-rds-data-api"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds-data:*"
        ],
        Resource = var.aurora_arn
      },
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = "${var.aurora_secret_arn}*"
      }
    ]
  })
}

# RDS, S3, KMS, Titan 임베딩 모델 접근 권한 정책
resource "aws_iam_policy" "rds_access_policy" {
  name = "${var.knowledge_base_name}-rds-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rds:Describe*",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = "${var.aurora_secret_arn}*"
      },
      {
        Effect   = "Allow",
        Action   = ["kms:Decrypt"],
        Resource = aws_kms_key.bedrock_kb_key.arn
      },
      {
        Effect   = "Allow",
        Action   = ["bedrock:InvokeModel"],
        Resource = "arn:aws:bedrock:ap-northeast-2::foundation-model/amazon.titan-embed-text-v2:0"
      }
    ]
  })
}

# 정책 연결
resource "aws_iam_role_policy_attachment" "attach_data_api" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = aws_iam_policy.rds_data_api_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_rds_access" {
  role       = aws_iam_role.bedrock_kb_role.name
  policy_arn = aws_iam_policy.rds_access_policy.arn
}

# IAM 연결 지연 방지용 딜레이
resource "time_sleep" "wait_10s" {
  create_duration = "10s"
  depends_on      = [aws_iam_role_policy_attachment.attach_rds_access]
}

# Bedrock Knowledge Base 생성
resource "aws_bedrockagent_knowledge_base" "main" {
  name     = var.knowledge_base_name
  role_arn = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:ap-northeast-2::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  storage_configuration {
    type = "RDS"
    rds_configuration {
      credentials_secret_arn = var.aurora_secret_arn
      database_name          = var.aurora_db_name
      resource_arn           = var.aurora_arn
      table_name             = var.aurora_table_name
      field_mapping {
        primary_key_field = var.aurora_primary_key_field
        text_field        = var.aurora_text_field
        metadata_field    = var.aurora_metadata_field
        vector_field      = var.aurora_vector_field
      }
    }
  }

  depends_on = [time_sleep.wait_10s]
}

# S3 데이터 소스 연결 (Terraform에서는 chunking 제거)
resource "aws_bedrockagent_data_source" "s3_data_source" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  name              = "${var.knowledge_base_name}-s3"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.s3_bucket_arn
    }
  }

  # Terraform이 chunking 설정을 무시하도록 구성
  lifecycle {
    ignore_changes = [data_source_configuration]
  }

  depends_on = [aws_bedrockagent_knowledge_base.main]
}
