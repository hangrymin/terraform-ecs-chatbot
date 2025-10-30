# Nova Pro 호출과 동일 리전을 권장 (현재 us-east-1)
region = "us-east-1"

guardrail_name = "etevers-chat-guardrail"
ssm_prefix     = "/chatbot/guardrail"

blocked_input_message  = "개인정보/부적절한 표현에 대한 요청은 답변 드릴 수 없습니다."
blocked_output_message = "개인정보/부적절한 표현에 대한 응답은 제공되지 않습니다."
