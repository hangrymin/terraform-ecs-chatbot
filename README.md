# 🤖 Terraform ECS Chatbot (AWS Bedrock 기반)

Terraform을 이용하여 **AWS ECS Fargate 기반 Bedrock Chatbot 인프라**를 자동으로 배포하는 프로젝트입니다.  
이 프로젝트는 인프라 코드(IaC) 방식을 통해 **ECS 클러스터, ALB, S3, Aurora, SSM, Bedrock Knowledge Base**를 자동 구성합니다.
기술 교육을 목적으로 제작되었습니다.

---

## 🏗️ 주요 아키텍처 구성

```plaintext
[User] ─▶ [ALB] ─▶ [ECS (Fargate)]
                     │
                     ├─ Streamlit Chatbot (Nova Pro + RAG)
                     ├─ Bedrock Knowledge Base + Rerank
                     └─ Aurora Serverless (Vector DB)

```

---


- **ECS Fargate**: 서버리스 컨테이너 기반 챗봇 실행 환경  
- **Amazon Bedrock**: Nova Pro 모델 + Knowledge Base + Rerank를 통한 RAG 기반 응답  
- **Aurora Serverless**: Knowledge Base 벡터 데이터 저장  
- **S3**: 문서 데이터 및 모델 입력 소스 저장  
- **SSM Parameter Store**: Bedrock KB ID 및 Guardrail 설정 자동 주입  
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
│   ├── bedrock_client.py
│   ├── streamlit_ui.py
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

- **모듈화된 앱 구조**: bedrock_client.py (비즈니스 로직) + streamlit_ui.py (UI)
- **멀티 리전 Bedrock 활용**: Nova Pro (us-east-1), KB (ap-northeast-2), Rerank (ap-northeast-1)
- **조건부 ECS 서비스 생성**: 이미지 준비 상태에 따른 자동 배포
- **RAG 시스템**: Knowledge Base + Rerank로 정확도 향상
- **보안 강화**: Guardrail + PII 마스킹 이중 보안
- **포괄적 로깅**: CloudWatch를 통한 디버깅 및 모니터링
- **SSM 기반 설정 관리**: KB ID, Guardrail 정보 자동 주입

---

## 🧑‍💻 Maintainer

Author: LEE MINGYU
Email: [mingyu.lee@etevers.com](mailto:mingyu.lee@etevers.com)


## ⚖️ License  
이 프로젝트는 **MIT License**를 따릅니다.

---