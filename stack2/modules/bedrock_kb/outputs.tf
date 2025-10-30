// === Standardized Outputs (권장 사용) ===

output "knowledge_base_id" {
  value       = aws_bedrockagent_knowledge_base.main.id
  description = "Knowledge Base ID (for external references / SSM registration)"
}

output "knowledge_base_arn" {
  value       = aws_bedrockagent_knowledge_base.main.arn
  description = "Knowledge Base ARN (for IAM / policy references)"
}

// === Backward Compatibility (선택적 유지: 향후 제거 예정) ===
// Deprecated: use knowledge_base_arn instead
output "arn" {
  value       = aws_bedrockagent_knowledge_base.main.arn
  description = "[Deprecated] Use 'knowledge_base_arn' instead."
}

// Deprecated: use knowledge_base_id instead
output "id" {
  value       = aws_bedrockagent_knowledge_base.main.id
  description = "[Deprecated] Use 'knowledge_base_id' instead."
}

// (선택) 사용된 KMS Key ARN 출력 - 주입된 경우에만 유용
output "kms_key_arn" {
  value       = var.kms_key_arn
  description = "KMS key ARN used to decrypt documents"
}
