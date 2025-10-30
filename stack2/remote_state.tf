# 로컬 backend 사용 시, stack1의 tfstate 경로를 직접 참조
data "terraform_remote_state" "stack1" {
  backend = "local"
  config = {
    # stack2 디렉터리 기준 상대 경로 예시
    path = "../stack1/terraform.tfstate"
  }
}
