data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# S3 버킷 생성: 문서 저장용
resource "aws_s3_bucket" "docs" {
  bucket        = var.bucket_name
  force_destroy = true # 버킷 비워지지 않아도 강제 삭제

  tags = {
    Name = var.bucket_name
  }
}

# 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# SSE-S3(AES256) 기반의 AWS 관리형 키로 기본 암호화 구성
resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # AWS 관리형 키 사용
    }
  }
}

# 버전 관리 활성화
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.docs.id

  versioning_configuration {
    status = "Enabled"
  }
}
