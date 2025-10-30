# 리전 값
variable "region_use1" {
  description = "LLM 로그 수집 리전"
  type        = string
  default     = "us-east-1"
}

# 공통 로그 설정
variable "log_group_name" {
  description = "CloudWatch 로그 그룹명 / CloudWatch Logs group name"
  type        = string
  default     = "/bedrock/model-invocations"
}

variable "log_group_retention_in_days" {
  description = "로그 보관 기간(일) / Retention days"
  type        = number
  default     = 7
}

# 데이터 유형 토글
variable "log_text_data_enabled" {
  description = "텍스트 입력/출력 로깅"
  type        = bool
  default     = true
}

variable "log_image_data_enabled" {
  description = "이미지 로깅"
  type        = bool
  default     = false
}

variable "log_embedding_data_enabled" {
  description = "임베딩 로깅"
  type        = bool
  default     = false
}

variable "log_video_data_enabled" {
  description = "비디오 로깅"
  type        = bool
  default     = false
}

# (옵션) 대용량 S3 전달
variable "enable_s3_large_delivery" {
  description = "S3 대용량 전달 사용"
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "S3 버킷명 (null이면 자동 생성)"
  type        = string
  default     = null
}

variable "s3_prefix" {
  description = "S3 key prefix (예: invocations/)"
  type        = string
  default     = "invocations/"
}
