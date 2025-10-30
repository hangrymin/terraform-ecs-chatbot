output "guardrail_arn" {
  value       = aws_bedrock_guardrail.chat_guardrail.guardrail_arn
  description = "생성된 Guardrail의 ARN"
}

output "guardrail_version" {
  value       = aws_bedrock_guardrail_version.chat_guardrail_v1.version
  description = "발행된 Guardrail 버전 (예: 1)"
}

output "ssm_params" {
  value = {
    arn_param     = aws_ssm_parameter.gr_arn.name
    version_param = aws_ssm_parameter.gr_ver.name
    region_param  = aws_ssm_parameter.gr_region.name
  }
  description = "앱에서 사용할 SSM 파라미터 키"
}
