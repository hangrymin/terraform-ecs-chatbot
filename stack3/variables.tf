variable "region" {
  description = "Guardrail 리전"
  type        = string
  default     = "us-east-1"
}

variable "guardrail_name" {
  description = "Guardrail 이름"
  type        = string
  default     = "etevers-chat-guardrail"
}

variable "blocked_input_message" {
  description = "차단된 입력에 대한 사용자 안내 문구"
  type        = string
  default     = "개인정보/부적절한 표현에 대한 요청은 답변 드릴 수 없습니다."
}

variable "blocked_output_message" {
  description = "차단된 출력(모델 응답)에 대한 사용자 안내 문구"
  type        = string
  default     = "개인정보/부적절한 표현에 대한 응답은 제공되지 않습니다."
}

variable "ssm_prefix" {
  description = "SSM 파라미터 프리픽스"
  type        = string
  default     = "/chatbot/guardrail"
}
