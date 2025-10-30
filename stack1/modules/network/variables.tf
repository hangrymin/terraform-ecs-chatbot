# 리소스 이름에 공통으로 사용할 접두사 (예: chatbot)
variable "name_prefix" {
  type        = string
  description = "이름 prefix"
}

# 생성할 VPC의 CIDR 블록 (예: 10.0.0.0/16)
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR 블록"
}

# 사용할 가용 영역(Availability Zones)의 리스트 (예: ["ap-northeast-2a", "ap-northeast-2c"])
variable "azs" {
  type        = list(string)
  description = "사용할 가용 영역 리스트"
}

# 퍼블릭 및 프라이빗 서브넷의 CIDR 블록 정의
variable "subnet_cidrs" {
  type = object({
    public  = list(string)
    private = list(string)
  })
  description = "퍼블릭 및 프라이빗 서브넷 CIDR 블록"
}
