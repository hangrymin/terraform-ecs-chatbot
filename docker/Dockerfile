FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 필수 패키지 최소 설치 후 캐시 정리
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 사용자 생성 (보안)
RUN useradd -m -u 10001 appuser

# 로그 디렉터리 미리 생성 (코드가 LOG_DIR 사용)
RUN mkdir -p /var/log/app && chown -R appuser:appuser /var/log/app
ENV LOG_DIR=/var/log/app

# 작업 디렉터리
WORKDIR /app

# 의존성 설치 (캐시 최적화: requirements 먼저 복사)
COPY app/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# 앱 소스 복사
COPY app/ /app/
RUN chown -R appuser:appuser /app

# ALB/TG가 8501로 포워딩하므로 Streamlit도 8501로 구동
ENV STREAMLIT_SERVER_PORT=8501
ENV STREAMLIT_SERVER_HEADLESS=true
# 기본 리전(코드에서 개별 클라이언트 리전을 지정해도 무방)
ENV AWS_REGION=ap-northeast-2
ENV AWS_DEFAULT_REGION=ap-northeast-2

EXPOSE 8501

# 비루트로 실행
USER appuser

# 메인 엔트리 (컨테이너 내부 경로는 /app 기준)
CMD ["streamlit", "run", "streamlit_ui.py", \
     "--server.port=8501", \
     "--server.address=0.0.0.0", \
     "--server.headless=true", \
     "--browser.gatherUsageStats=false", \
     "--server.enableCORS=false"]
# 운영 배포 땐 XSRF 기본(true) 유지 권장 → --server.enableXsrfProtection 인자는 생략
