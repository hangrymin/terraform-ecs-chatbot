# 모듈 입력 변수 / Module inputs

variable "region" {
  description = "AWS Region (리전)"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch 로그 그룹명 / CloudWatch Logs group name"
  type        = string
}

variable "log_group_retention_in_days" {
  description = "CloudWatch 로그 보관기간(일) / Retention in days"
  type        = number
  default     = 7
}

# 로깅할 데이터 유형 / Data types to log
variable "log_text_data_enabled" {
  description = "텍스트 입력/출력 로깅 / Log text inputs/outputs"
  type        = bool
  default     = true
}
variable "log_image_data_enabled" {
  description = "이미지 로깅 / Log image data"
  type        = bool
  default     = false
}
variable "log_embedding_data_enabled" {
  description = "임베딩 로깅 / Log embedding data"
  type        = bool
  default     = false
}
variable "log_video_data_enabled" {
  description = "비디오 로깅 / Log video data"
  type        = bool
  default     = false
}

# (옵션) 대용량/바이너리 S3 전달 / Optional S3 large data delivery
variable "enable_s3_large_delivery" {
  description = "S3 대용량 전달 사용 / Enable S3 for large data"
  type        = bool
  default     = false
}
variable "s3_bucket_name" {
  description = "S3 버킷명(미입력 시 자동 생성) / S3 bucket name (auto if null)"
  type        = string
  default     = null
}
variable "s3_prefix" {
  description = "S3 key prefix (예: invocations/) / S3 key prefix"
  type        = string
  default     = "invocations/"
}
