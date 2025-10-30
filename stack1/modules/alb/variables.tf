# 리소스 이름 prefix
variable "name_prefix" {
  type = string
}

# VPC ID
variable "vpc_id" {
  type = string
}

# ALB에 적용할 보안 그룹 ID
variable "alb_sg_id" {
  type = string
}

# ALB가 배치될 퍼블릭 서브넷 목록
variable "public_subnet_ids" {
  type = list(string)
}

# 타겟으로 연결할 EC2 인스턴스 ID 목록 (사용하지 않음)
# variable "target_instance_ids" {
#   type = list(string)
# }
