output "use1_log_group_name" {
  description = "us-east-1 CloudWatch Logs 그룹명"
  value       = module.logs_use1.log_group_name
}

output "use1_iam_role_arn" {
  description = "us-east-1 Bedrock이 Assume하는 IAM Role ARN"
  value       = module.logs_use1.iam_role_arn
}

output "use1_s3_bucket_name" {
  description = "us-east-1 대용량 전달 S3 버킷명(옵션)"
  value       = module.logs_use1.s3_bucket_name
}

output "use1_effective_logging_flags" {
  description = "us-east-1 텍스트/이미지/임베딩/비디오 및 S3 대용량 전달 ON/OFF"
  value       = module.logs_use1.effective_logging_flags
}
