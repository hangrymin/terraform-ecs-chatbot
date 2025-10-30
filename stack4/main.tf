terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79.0"
    }
  }
}

provider "aws" {
  region = var.region_use1
}

module "logs_use1" {
  source = "./modules/bedrock_invocation_logging"

  region                      = var.region_use1
  log_group_name              = var.log_group_name
  log_group_retention_in_days = var.log_group_retention_in_days

  # 로깅 데이터 유형 토글
  log_text_data_enabled       = var.log_text_data_enabled
  log_image_data_enabled      = var.log_image_data_enabled
  log_embedding_data_enabled  = var.log_embedding_data_enabled
  log_video_data_enabled      = var.log_video_data_enabled

  # (옵션) S3 대용량 전달
  enable_s3_large_delivery = var.enable_s3_large_delivery
  s3_bucket_name           = var.s3_bucket_name
  s3_prefix                = var.s3_prefix
}
