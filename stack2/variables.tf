# stack2/variables.tf

# Bedrock Knowledge Base 기본 정보
variable "knowledge_base_name" {
  description = "Bedrock Knowledge Base 이름"
  type        = string
}

variable "knowledge_base_description" {
  description = "Bedrock Knowledge Base 설명"
  type        = string
}

# Aurora 연동 정보
variable "aurora_arn" {
  description = "Aurora DB 클러스터의 ARN"
  type        = string
}

variable "aurora_db_name" {
  description = "Aurora DB 이름"
  type        = string
}

variable "aurora_endpoint" {
  description = "Aurora DB 엔드포인트"
  type        = string
}

variable "aurora_table_name" {
  description = "RAG에 사용할 테이블 이름"
  type        = string
}

variable "aurora_primary_key_field" {
  description = "기본 키 필드 이름"
  type        = string
}

variable "aurora_metadata_field" {
  description = "메타데이터 필드 이름"
  type        = string
}

variable "aurora_text_field" {
  description = "본문 텍스트 필드 이름"
  type        = string
}

variable "aurora_vector_field" {
  description = "벡터 필드 이름"
  type        = string
}

variable "aurora_username" {
  description = "DB 접속용 사용자 이름"
  type        = string
}

variable "aurora_secret_arn" {
  description = "Aurora 접속용 Secrets Manager ARN"
  type        = string
}

# 문서가 저장된 S3 버킷 ARN
variable "s3_bucket_arn" {
  description = "Bedrock KB에서 참조할 S3 버킷 ARN"
  type        = string
}

# ap-northeast-2
variable "kb_id_ssm_parameter_name" {
  description = "생성된 KB ID를 저장할 Systems Manager Parameter 이름"
  type        = string
}

# us-east-1
variable "guardrail_ssm_prefix" {
  description = "Guardrail SSM 파라미터 프리픽스(us-east-1). 예: /chatbot/guardrail"
  type        = string
  default     = "/chatbot/guardrail"
}

# ECS 컨테이너 이미지 (ECR URI 등)
variable "chatbot_image" {
  description = "ECS에서 실행할 컨테이너 이미지 (ECR URI 등)"
  type        = string
}

# ECS 컨테이너 로그 그룹명
variable "chatbot_log_group_name" {
  description = "컨테이너 로그가 전송될 CloudWatch Log Group 이름"
  type        = string
  default     = "/chatbot/ecs-app"
}

# ECS 서비스 기본 desired count
variable "desired_count" {
  description = "ECS 서비스의 초기 desired task 개수"
  type        = number
  default     = 1
}
