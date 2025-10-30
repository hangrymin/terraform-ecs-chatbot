terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.10.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Bedrock Guardrail: PII + 욕설(관리형 리스트)
resource "aws_bedrock_guardrail" "chat_guardrail" {
  name        = var.guardrail_name
  description = "ETEVERS chatbot guardrail (PII + Profanity block)"

  # 차단 시 사용자 안내 문구
  blocked_input_messaging   = var.blocked_input_message
  blocked_outputs_messaging = var.blocked_output_message

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "IP_ADDRESS"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "US_BANK_ACCOUNT_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
  }

  # 욕설 차단: 관리형 리스트(PROFANITY)
  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}

# Guardrail 발행 버전(v1)
resource "aws_bedrock_guardrail_version" "chat_guardrail_v1" {
  guardrail_arn = aws_bedrock_guardrail.chat_guardrail.guardrail_arn
  description   = "v1"
}

resource "aws_ssm_parameter" "gr_arn" {
  name  = "${var.ssm_prefix}/arn"
  type  = "String"
  value = aws_bedrock_guardrail.chat_guardrail.guardrail_arn
}

resource "aws_ssm_parameter" "gr_ver" {
  name  = "${var.ssm_prefix}/version"
  type  = "String"
  value = aws_bedrock_guardrail_version.chat_guardrail_v1.version
}

resource "aws_ssm_parameter" "gr_region" {
  name  = "${var.ssm_prefix}/region"
  type  = "String"
  value = var.region
}

resource "aws_ssm_parameter" "gr_id" {
  name  = "${var.ssm_prefix}/id"
  type  = "String"
  value = aws_bedrock_guardrail.chat_guardrail.guardrail_arn
}
