terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79.0"
    }
  }
}

data "aws_caller_identity" "this" {}

locals {
  account_id = data.aws_caller_identity.this.account_id
  partition  = "aws"
  region     = var.region
}

# 1) CloudWatch Log Group
resource "aws_cloudwatch_log_group" "invocations" {
  name              = var.log_group_name
  retention_in_days = var.log_group_retention_in_days
}

# 2) IAM Role for Bedrock → CW Logs
resource "aws_iam_role" "bedrock_logging_role" {
  name = "bedrock-invocation-logging-role-${local.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "bedrock.amazonaws.com" },
      Action   = "sts:AssumeRole",
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id },
        ArnLike      = { "aws:SourceArn"     = "arn:${local.partition}:bedrock:${local.region}:${local.account_id}:*" }
      }
    }]
  })
}

# 2-b) Role permissions to write to CloudWatch Logs
resource "aws_iam_role_policy" "bedrock_logging_to_cw" {
  name = "bedrock-invocation-logging-to-cw-${local.region}"
  role = aws_iam_role.bedrock_logging_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      Resource = [
        aws_cloudwatch_log_group.invocations.arn,
        "${aws_cloudwatch_log_group.invocations.arn}:*"
      ]
    }]
  })
}

# 3) (옵션) S3 for large data delivery (>100KB or binary)
resource "aws_s3_bucket" "invocation_logs" {
  count  = var.enable_s3_large_delivery ? 1 : 0
  bucket = var.s3_bucket_name != null ? var.s3_bucket_name : "bedrock-invocation-logs-${local.account_id}-${local.region}"
  force_destroy = false

  tags = { Name = "bedrock-invocation-logs" }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count  = var.enable_s3_large_delivery ? 1 : 0
  bucket = aws_s3_bucket.invocation_logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  count  = var.enable_s3_large_delivery ? 1 : 0
  bucket = aws_s3_bucket.invocation_logs[0].id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_policy" "allow_bedrock_put" {
  count  = var.enable_s3_large_delivery ? 1 : 0
  bucket = aws_s3_bucket.invocation_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid      = "AmazonBedrockLogsWrite",
      Effect   = "Allow",
      Principal = { Service = "bedrock.amazonaws.com" },
      Action   = ["s3:PutObject"],
      Resource = [
        "arn:${local.partition}:s3:::${aws_s3_bucket.invocation_logs[0].bucket}/${var.s3_prefix}AWSLogs/${local.account_id}/BedrockModelInvocationLogs/*"
      ],
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id },
        ArnLike      = { "aws:SourceArn"     = "arn:${local.partition}:bedrock:${local.region}:${local.account_id}:*" }
      }
    }]
  })
}

# 4) Bedrock model invocation logging configuration (region-scoped singleton)
resource "aws_bedrock_model_invocation_logging_configuration" "this" {
  logging_config {
    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.invocations.name
      role_arn       = aws_iam_role.bedrock_logging_role.arn

      # (옵션) 대용량 S3 전달
      dynamic "large_data_delivery_s3_config" {
        for_each = var.enable_s3_large_delivery ? [1] : []
        content {
          bucket_name = aws_s3_bucket.invocation_logs[0].bucket
          key_prefix  = var.s3_prefix
        }
      }
    }

    # 데이터 유형 토글
    text_data_delivery_enabled      = var.log_text_data_enabled
    image_data_delivery_enabled     = var.log_image_data_enabled
    embedding_data_delivery_enabled = var.log_embedding_data_enabled
    video_data_delivery_enabled     = var.log_video_data_enabled
  }
}
