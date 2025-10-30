# CloudWatch 로그 그룹 이름 (앱/컨테이너 로그용)
variable "chatbot_log_group_name" {
  description = "컨테이너/앱 로그를 보관할 CloudWatch 로그 그룹 이름"
  type        = string
  default     = "/chatbot/ecs-app"
}

# CloudWatch 로그 보존 기간 (일)
variable "chatbot_log_retention_days" {
  description = "컨테이너/앱 로그 보존 기간 (일)"
  type        = number
  default     = 7
}