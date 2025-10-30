# CloudWatch 로그 그룹명 / CloudWatch Logs group name
output "log_group_name" {
  value       = aws_cloudwatch_log_group.invocations.name
  description = "CloudWatch 로그 그룹명 / CloudWatch log group name"
}

# Bedrock이 Assume하는 IAM 역할 ARN / Role ARN assumed by Bedrock
output "iam_role_arn" {
  value       = aws_iam_role.bedrock_logging_role.arn
  description = "Bedrock이 Assume하는 역할 ARN / IAM Role ARN for Bedrock"
}

# (옵션) 대용량 전달 버킷명 / Optional large-delivery S3 bucket name
output "s3_bucket_name" {
  value       = try(aws_s3_bucket.invocation_logs[0].bucket, null)
  description = "대용량 전달용 S3 버킷명(옵션) / S3 bucket for large data (optional)"
}

# 운영 점검에 유용한 플래그 / Effective flags for quick verification
output "effective_logging_flags" {
  description = "텍스트/이미지/임베딩/비디오 및 S3 대용량 전달 ON/OFF 상태"
  value = {
    text_data_enabled      = aws_bedrock_model_invocation_logging_configuration.this.logging_config[0].text_data_delivery_enabled
    image_data_enabled     = aws_bedrock_model_invocation_logging_configuration.this.logging_config[0].image_data_delivery_enabled
    embedding_data_enabled = aws_bedrock_model_invocation_logging_configuration.this.logging_config[0].embedding_data_delivery_enabled
    s3_large_delivery_on   = length(aws_bedrock_model_invocation_logging_configuration.this.logging_config[0].cloudwatch_config[0].large_data_delivery_s3_config) > 0
    video_data_enabled     = aws_bedrock_model_invocation_logging_configuration.this.logging_config[0].video_data_delivery_enabled
  }
}
