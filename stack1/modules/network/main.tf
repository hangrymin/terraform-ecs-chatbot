# VPC 생성
resource "aws_vpc" "chatbot_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "chatbot_public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.chatbot_vpc.id
  cidr_block        = var.subnet_cidrs.public[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.name_prefix}-public-${count.index + 1}"
  }
}

# 프라이빗 서브넷 생성
resource "aws_subnet" "chatbot_private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.chatbot_vpc.id
  cidr_block        = var.subnet_cidrs.private[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.name_prefix}-private-${count.index + 1}"
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "chatbot_igw" {
  vpc_id = aws_vpc.chatbot_vpc.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# 퍼블릭 라우팅 테이블 생성
resource "aws_route_table" "chatbot_public" {
  vpc_id = aws_vpc.chatbot_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.chatbot_igw.id
  }
}

# 퍼블릭 서브넷에 라우팅 테이블 연결
resource "aws_route_table_association" "chatbot_public" {
  count          = length(aws_subnet.chatbot_public)
  subnet_id      = aws_subnet.chatbot_public[count.index].id
  route_table_id = aws_route_table.chatbot_public.id
}

# NAT 게이트웨이용 탄력 IP 생성
resource "aws_eip" "chatbot_nat_eip" {
  domain = "vpc"
}

# NAT 게이트웨이 생성
resource "aws_nat_gateway" "chatbot_nat" {
  allocation_id = aws_eip.chatbot_nat_eip.id
  subnet_id     = aws_subnet.chatbot_public[0].id

  tags = {
    Name = "${var.name_prefix}-nat"
  }
}

# 프라이빗 라우팅 테이블 생성
resource "aws_route_table" "chatbot_private" {
  vpc_id = aws_vpc.chatbot_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.chatbot_nat.id
  }
}

# 프라이빗 서브넷에 라우팅 테이블 연결
resource "aws_route_table_association" "chatbot_private" {
  count          = length(aws_subnet.chatbot_private)
  subnet_id      = aws_subnet.chatbot_private[count.index].id
  route_table_id = aws_route_table.chatbot_private.id
}
