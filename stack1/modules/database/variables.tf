# Aurora 클러스터 식별자 (클러스터 이름)
variable "cluster_identifier" {
  type        = string
  description = "RDS 클러스터 식별자"
}

# Aurora PostgreSQL 엔진 버전: 기본값: 15.4 > 16.6 변경
variable "engine_version" {
  type    = string
  default = "16.6"
}

# 초기 생성할 기본 데이터베이스 이름
variable "database_name" {
  type    = string
  default = "chatapp"
}

# 마스터 사용자 계정명 (기본값: dbadmin)
variable "master_username" {
  type    = string
  default = "chatadmin"
}

# 배포 대상 VPC ID
variable "vpc_id" {
  type = string
}

# 프라이빗 서브넷 ID 목록 (Aurora 클러스터에 연결될 서브넷)
variable "subnet_ids" {
  type = list(string)
}

# Aurora에 접근 허용할 CIDR 블록 (기본값: VPC 전체)
variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

# Serverless v2 최대 용량 (ACU 단위)
variable "max_capacity" {
  type    = number
  default = 1
}

# Serverless v2 최소 용량 (ACU 단위)
variable "min_capacity" {
  type    = number
  default = 0.5
}
