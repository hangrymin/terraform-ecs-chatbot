// Knowledge Base의 이름
variable "knowledge_base_name" {
  type = string
}

// Knowledge Base의 설명
variable "knowledge_base_description" {
  type = string
}

// Aurora 클러스터의 ARN
variable "aurora_arn" {
  type = string
}

// Aurora 데이터베이스 이름
variable "aurora_db_name" {
  type = string
}

// Aurora 엔드포인트 (미사용 중일 수 있음)
variable "aurora_endpoint" {
  type = string
}

// Knowledge Base에서 사용할 테이블 이름
variable "aurora_table_name" {
  type = string
}

// Aurora 사용자명 (보통 Secrets Manager를 통해 접근)
variable "aurora_username" {
  type = string
}

// Aurora 자격 증명용 Secret ARN (Secrets Manager)
variable "aurora_secret_arn" {
  type = string
}

// 벡터 필드 이름
variable "aurora_vector_field" {
  type = string
}

// 질문/문서 본문 텍스트 필드 이름
variable "aurora_text_field" {
  type = string
}

// 메타데이터 필드 이름
variable "aurora_metadata_field" {
  type = string
}

// 기본 키 필드 이름
variable "aurora_primary_key_field" {
  type = string
}

// Knowledge Base에서 사용할 S3 버킷 ARN
variable "s3_bucket_arn" {
  type = string
}

// (선택) S3에서 암호화된 객체를 해독하기 위한 KMS Key ARN
// null이면 기본 KMS 키를 사용하거나 KMS 정책에 따라 오류 발생 가능
variable "kms_key_arn" {
  description = "Optional: KMS key ARN used to decrypt S3 files. Required if your bucket uses KMS encryption."
  type        = string
  default     = null
}