# Terraform Provider 설정
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.76.0"
    }
  }
}

# AWS Provider (서울 리전)
provider "aws" {
  region = "ap-northeast-2"
}

# VPC 및 서브넷 구성
module "network" {
  source      = "./modules/network"
  name_prefix = "chat"
  vpc_cidr    = "10.0.0.0/16"
  azs         = ["ap-northeast-2a", "ap-northeast-2c"]
  subnet_cidrs = {
    public  = ["10.0.1.0/24", "10.0.2.0/24"]
    private = ["10.0.6.0/24", "10.0.7.0/24"]
  }
}

# 보안 그룹 (ALB 전용)
module "security" {
  source      = "./modules/security"
  name_prefix = "chat"
  vpc_id      = module.network.vpc_id
}

# 현재 계정 정보 (S3 버킷 이름 생성에 사용)
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "bedrock-kb-${data.aws_caller_identity.current.account_id}"
}

# S3 버킷 (문서 저장용)
module "s3" {
  source      = "./modules/s3"
  bucket_name = local.bucket_name
}

# ALB 설정 (ECS(TargetType=ip)용 TG 사용)
module "alb" {
  source            = "./modules/alb"
  name_prefix       = "chat"
  vpc_id            = module.network.vpc_id
  alb_sg_id         = module.security.alb_sg_id
  public_subnet_ids = module.network.public_subnet_ids
}

# Aurora Serverless v2 (RAG 저장용)
module "aurora" {
  source = "./modules/database"

  cluster_identifier  = "chat-aurora-serverless"
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids
  database_name       = "chatapp"
  master_username     = "chatadmin"
  max_capacity        = 1
  min_capacity        = 0.5
  allowed_cidr_blocks = ["10.0.0.0/16"]
}

# CloudWatch 로그 그룹 (ECS 컨테이너 로그)
resource "aws_cloudwatch_log_group" "chatbot_app" {
  name              = var.chatbot_log_group_name
  retention_in_days = var.chatbot_log_retention_days
}
