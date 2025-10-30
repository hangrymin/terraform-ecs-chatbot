resource "aws_ecr_repository" "chatbot" {
  name                 = "chatbot"
  image_tag_mutability = "MUTABLE" # 운영은 IMMUTABLE 권장
  force_delete         = true      # 삭제 편의(운영은 false 권장)

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256" # KMS 쓰려면 "KMS" + kms_key
  }

  tags = { Project = "chatbot" }
}

# 최근 10개 이미지 외 정리(원하면 유지개수 조절)
resource "aws_ecr_lifecycle_policy" "chatbot" {
  repository = aws_ecr_repository.chatbot.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "Keep last 10 images",
      selection = {
        tagStatus   = "any",
        countType   = "imageCountMoreThan",
        countNumber = 10
      },
      action = { type = "expire" }
    }]
  })
}

output "ecr_repository_url" {
  value = aws_ecr_repository.chatbot.repository_url
}
