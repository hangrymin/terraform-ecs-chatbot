# 🤖 Terraform ECS Chatbot (AWS Bedrock 기반)

Terraform을 이용하여 **AWS ECS Fargate 기반 Bedrock Chatbot 인프라**를 자동으로 배포하는 프로젝트입니다.  
이 프로젝트는 인프라 코드(IaC) 방식을 통해 **ECS 클러스터, ALB, S3, Aurora, SSM, Bedrock Knowledge Base**를 자동 구성합니다.
기술 교육을 목적으로 제작되었습니다.

---

## 🏗️ 주요 아키텍처 구성

```plaintext
[User] ─▶ [ALB] ─▶ [ECS (Fargate)]
                     │
                     ├─ Streamlit Chatbot (Nova / Titan 기반)
                     ├─ Bedrock Knowledge Base (RAG 기반)
                     └─ Aurora Serverless (Document Metadata 저장)

```

---


- **ECS Fargate**: 서버리스 컨테이너 기반 챗봇 실행 환경  
- **Amazon Bedrock**: Nova / Titan 모델을 통한 자연어 응답  
- **Aurora Serverless**: 대화 로그 및 메타데이터 저장  
- **S3**: 문서 데이터 및 모델 입력 소스 저장  
- **SSM Parameter Store**: Bedrock KB ID 자동 주입  
- **ALB**: HTTP 트래픽을 ECS로 라우팅  

---

## 🚀 배포 절차

### 🧩 Stack 구조

| Stack | 주요 리소스 | 설명 |
|:------|:-------------|:-----|
| **stack1** | VPC, Subnet, ALB, IAM, Aurora, S3, SecurityGroup | 기본 인프라 리소스 |
| **stack2** | Bedrock KB, ECS Service(Task), SSM Parameter | AI 챗봇 서비스 구성 |
| **stack3** | Bedrock Guardrails | 책임 있는 AI 정책에 맞게 사용자 지정된 보호 장치를 구현 |
| **stack4** | Bedrock LLM Invocation Logging | LLM 호출 로그 수집 및 분석 |

### 주요 Terraform 모듈 구조
```bash
tf-workspace/
├── app
│   ├── __pycache__
│   │   └── app_core.cpython-313.pyc
│   ├── app_core.py
│   ├── app_nova_pro_prompt_template.py
│   └── requirements.txt
├── contents
│   └── 금융분야 클라우드컴퓨팅서비스 이용 가이드.pdf
├── docker
│   └── Dockerfile
├── logs
│   └── streamlit_chatbot.log
├── README.md
├── scripts
│   └── aurora.sql
├── stack1
│   ├── main.tf
│   ├── modules
│   │   ├── alb
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── database
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── network
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── s3
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   └── security
│   │       ├── main.tf
│   │       ├── outputs.tf
│   │       └── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── stack2
│   ├── ecr.tf
│   ├── ecs.tf
│   ├── main.tf
│   ├── modules
│   │   └── bedrock_kb
│   │       ├── main.tf
│   │       ├── outputs.tf
│   │       └── variables.tf
│   ├── outputs.tf
│   ├── remote_state.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── stack3
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── variables.tf
└── stack4
    ├── main.tf
    ├── modules
    │   └── bedrock_invocation_logging
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars
    └── variables.tf
```
---

## 📦 주요 기능

- Terraform 자동 배포 (VPC → ECS → Bedrock)
- Bedrock KB ID 자동 주입 (SSM Parameter)
- Aurora Serverless 기반 데이터 저장
- Nova / Titan 모델 기반 RAG 챗봇
- ALB + ECS Fargate 서버리스 구성
- Bedrock Guardrails로 책임 있는 AI 정책에 맞게 사용자 지정된 보호 장치를 구성
- CloudWatch 로그 및 Auto Scaling 구성 지원

---

## 🧑‍💻 Maintainer

Author: LEE MINGYU
Email: [mingyu.lee@etevers.com](mailto:mingyu.lee@etevers.com)


## ⚖️ License  
이 프로젝트는 **MIT License**를 따릅니다.

---