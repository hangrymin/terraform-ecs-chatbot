# === Aurora RDS 연결 정보 ===
aurora_arn        = "arn:aws:rds:ap-northeast-2:123456789:cluster:chat-aurora-serverless"                  # "출력된 aurora_arn"
aurora_endpoint   = "chat-aurora-serverless.cluster-123456789.ap-northeast-2.rds.amazonaws.com"            # "출력된 db_endpoint"
aurora_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:123456789:secret:chat-aurora-serverless-secret" # "출력된 aurora_secret_arn"
aurora_db_name    = "chatapp"
aurora_username   = "chatadmin"

# === Aurora 테이블 필드 매핑 ===
aurora_table_name        = "bedrock_integration.bedrock_kb"
aurora_primary_key_field = "id"
aurora_text_field        = "chunks"
aurora_metadata_field    = "metadata"
aurora_vector_field      = "embedding"

# === S3 버킷 ARN (stack1 output) ===
s3_bucket_arn = "arn:aws:s3:::bedrock-kb-123456789" # "출력된 s3_bucket_arn"

# === KB 설정 ===
knowledge_base_name        = "etevers-kb"
knowledge_base_description = "Aurora 기반 Bedrock Knowledge Base"

# === SSM Parameter 이름들 ===
# KB ID (ap-northeast-2)
kb_id_ssm_parameter_name = "/chatbot/bedrock/kb_id"

# === ECS 컨테이너 이미지/로그 ===
# 불변 태그 권장: v2 등으로 빌드/푸시 후 아래 값 갱신
chatbot_image          = "123456789.dkr.ecr.ap-northeast-2.amazonaws.com/chatbot:latest" # ecr 이미지 URI (예:12345678910.dkr.ecr.ap-northeast-2.amazonaws.com/chatbot:latest)
chatbot_log_group_name = "/chatbot/ecs-app"
desired_count          = 0 # 이미지 푸시 전에는 0으로 두고, ecr에 푸시 후 1로 변경
