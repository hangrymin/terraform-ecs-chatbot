# terraform Provider 설정
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.76.0"
    }
  }
}

# AWS Provider 설정 (서울 리전)
provider "aws" {
  region = "ap-northeast-2"
}

# # 현재 계정 ID 조회 (예: S3 버킷 명 구성 등에 사용 가능)
# data "aws_caller_identity" "current" {}

# Bedrock Knowledge Base 생성 모듈 호출
module "bedrock_kb" {
  source = "./modules/bedrock_kb"

  # Knowledge Base 이름 및 설명
  knowledge_base_name        = var.knowledge_base_name
  knowledge_base_description = var.knowledge_base_description

  # Aurora DB 정보
  aurora_arn               = var.aurora_arn
  aurora_db_name           = var.aurora_db_name
  aurora_endpoint          = var.aurora_endpoint
  aurora_table_name        = var.aurora_table_name
  aurora_primary_key_field = var.aurora_primary_key_field
  aurora_metadata_field    = var.aurora_metadata_field
  aurora_text_field        = var.aurora_text_field
  aurora_vector_field      = var.aurora_vector_field
  aurora_username          = var.aurora_username
  aurora_secret_arn        = var.aurora_secret_arn

  # 문서가 저장된 S3 버킷 ARN
  s3_bucket_arn = var.s3_bucket_arn
}

# Bedrock Knowledge Base ID를 EC2가 자동 읽을 수 있도록 SSM Parameter로 저장
resource "aws_ssm_parameter" "kb_id_param" {
  name  = var.kb_id_ssm_parameter_name
  type  = "String"
  value = module.bedrock_kb.knowledge_base_id

  tags = {
    Name = "bedrock-kb-id"
  }
}
