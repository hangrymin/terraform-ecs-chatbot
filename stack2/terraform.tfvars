# === Aurora RDS 연결 정보 ===
aurora_arn        = "" # "출력된 aurora_arn"
aurora_endpoint   = "" # "출력된 db_endpoint"
aurora_secret_arn = "" # "출력된 aurora_secret_arn"
aurora_db_name    = "chatapp"
aurora_username   = "chatadmin"

# === Aurora 테이블 필드 매핑 ===
aurora_table_name        = "bedrock_integration.bedrock_kb"
aurora_primary_key_field = "id"
aurora_text_field        = "chunks"
aurora_metadata_field    = "metadata"
aurora_vector_field      = "embedding"

# === S3 버킷 ARN (stack1 output) ===
s3_bucket_arn = "" # "출력된 s3_bucket_arn"

# === KB 설정 ===
knowledge_base_name        = "etevers-kb"
knowledge_base_description = "Aurora 기반 Bedrock Knowledge Base"

# === SSM Parameter 이름 ===
# KB ID (ap-northeast-2)
kb_id_ssm_parameter_name = "/chatbot/bedrock/kb_id"

# === ECS 컨테이너 이미지/로그 ===
# 초기 배포: 빈 문자열로 설정 (이미진 빌드 후 실제 URI로 변경)
chatbot_image          = "" # 이미지 빌드 후 실제 ECR URI로 변경
chatbot_log_group_name = "/chatbot/ecs-app"
desired_count          = 0 # 이미지 준비 후 1로 변경
