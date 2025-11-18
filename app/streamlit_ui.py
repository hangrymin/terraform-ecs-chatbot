# -*- coding: utf-8 -*-
"""
streamlit_ui.py

Streamlit 기반 챗봇 사용자 인터페이스

주요 기능:
1. 대화형 챗봇 UI 제공
2. Knowledge Base 검색 결과 시각화
3. 실시간 응답 생성 및 표시
4. 사용자 설정 관리 (시스템 프롬프트, 생성 옵션 등)
5. 세션 상태 관리 및 보안 처리

아키텍처:
- bedrock_client 모듈과 연동하여 비즈니스 로직 분리
- Streamlit 세션 상태로 대화 히스토리 관리
- 실시간 스트리밍 UI로 사용자 경험 최적화
"""

import os
import logging
from pathlib import Path
import streamlit as st

# bedrock_client 모듈에서 핵심 기능 import
from bedrock_client import (
    compose_prompt,          # 프롬프트 구성
    get_kb_id_from_ssm,     # KB ID 자동 조회
    mask_possible_pii,      # PII 마스킹
    query_kb,               # KB 검색 + Rerank
    invoke_nova_pro,        # Nova Pro 모델 호출
)

# =============================================================================
# 애플리케이션 설정
# =============================================================================

APP_VERSION = "build-20251118"

# 기본 시스템 프롬프트 (AWS 금융 클라우드 전문가 역할)
DEFAULT_SYSTEM_PROMPT = (
    "당신은 AWS 소개 및 제안, 금융분야 클라우드컴퓨팅서비스 전문가입니다. "
    "질문자의 배경지식이 완벽하지 않을 수 있음을 고려해, 쉬운 용어로 단계적으로 설명하되, "
    "필요한 경우 구체 예시와 권장 아키텍처, 고 링크(서비스명/프로그램명만)를 제시하세요. "
    "모호할 때는 필요한 사실을 먼저 확인하는 질문을 1~2개 던진 뒤 답하세요. "
    "허용된 지식베이스 문서에 근거해 답하며, 추정이 필요할 때는 '추정'임을 명확히 표기하세요."
)

# UI 아바타 설정
ASSISTANT_AVATAR = "🤖"  # AI 어시스턴트
USER_AVATAR = "🧑"       # 사용자


# =============================================================================
# 유틸리티 함수들
# =============================================================================

def setup_logging():
    """
    애플리케이션 로깅을 설정합니다.
    
    로그 디렉토리 우선순위:
    1. LOG_DIR 환경변수
    2. /var/log/app (컨테이너 환경)
    3. ./logs (로컬 개발 환경)
    
    Note:
        - 파일 로깅 실패 시에도 콘솔 로깅은 유지
        - Docker 컨테이너와 로컬 환경 모두 지원
    """
    # 로그 디렉토리 결정 (환경에 따른 자동 선택)
    log_dir = os.getenv("LOG_DIR")
    if not log_dir:
        try:
            # 컨테이너 환경 시도
            log_dir = "/var/log/app"
            Path(log_dir).mkdir(parents=True, exist_ok=True)
        except Exception:
            # 로컬 개발 환경 fallback
            log_dir = str(Path.cwd() / "logs")
            Path(log_dir).mkdir(parents=True, exist_ok=True)
    
    log_file = f"{log_dir}/streamlit_chatbot.log"
    
    # 로거 초기화
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # 기존 핸들러 제거 (중복 방지)
    for handler in list(logger.handlers):
        logger.removeHandler(handler)
    
    # 로그 포맷 설정
    formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
    
    # 파일 핸들러 (실패해도 계속 진행)
    try:
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    except Exception as e:
        logging.warning(f"로그 파일 생성 실패: {e}")
    
    # 콘솔 핸들러 (항상 활성화)
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    logging.info(f"Streamlit UI 시작 - 버전: {APP_VERSION}, 로그 디렉토리: {log_dir}")


def safe_unwrap_response(response):
    """
    Nova Pro 응답 튜플을 안전하게 언랩합니다.
    
    Args:
        response: invoke_nova_pro()의 반환값 (str, bool) 튜플 예상
        
    Returns:
        Tuple[str, bool]: (응답 텍스트, Guardrail 차단 여부)
        
    Note:
        - bedrock_client.invoke_nova_pro()는 항상 튜플을 반환하지만
        - 예외 상황에 대비한 방어적 프로그래밍
        - UI 레이어에서의 마지막 안전장치
    """
    try:
        if isinstance(response, tuple) and len(response) >= 2:
            return str(response[0]), bool(response[1])
        # 튜플이 아닌 경우 문자열로 변환하고 차단되지 않은 것으로 처리
        return str(response), False
    except Exception as e:
        return f"응답 처리 실패: {e}", False


def render_reranker_section(reranked, meta):
    """Reranker 결과 표시"""
    st.markdown("### 🔎 Reranker 결과")
    st.caption(f"검색 결과: **{meta.get('retrieved', 0)}건**")
    
    # 디버깅 로깅
    logging.info(f"[UI_DEBUG] reranked type: {type(reranked)}, length: {len(reranked) if reranked else 0}")
    if reranked:
        for i, item in enumerate(reranked[:2]):
            logging.info(f"[UI_DEBUG] reranked[{i}]: {str(item)[:100]}...")
    
    if meta.get("error"):
        st.warning(f"KB 검색 오류: {meta['error']}")
        return
    
    if reranked and len(reranked) > 0:
        cols = st.columns(min(3, len(reranked)))
        for i, (doc, score) in enumerate(reranked):
            with cols[i % len(cols)]:
                st.caption(f"Top {i+1} • 유사도 {score:.3f}")
                st.progress(min(max(score, 0.0), 1.0))
                with st.expander("본문 보기"):
                    if doc and doc.strip():
                        st.write(doc)
                    else:
                        st.write("빈 문서")
    else:
        st.info("관련 문서를 찾지 못했습니다. KB ID/리전, S3 인덱싱, 'KB 검색 결과 수'를 확인하세요.")


def main():
    """메인 UI 함수"""
    # 페이지 설정
    st.set_page_config(
        page_title="ETEVERS Bedrock Nova Pro 챗봇",
        page_icon="🤖",
        layout="wide",
        initial_sidebar_state="collapsed",
    )
    
    # 로깅 설정
    setup_logging()
    
    # 사이드바 설정
    st.sidebar.header("⚙️ 설정")
    default_kb_id = get_kb_id_from_ssm()
    kb_id = st.sidebar.text_input("Knowledge Base ID", value=default_kb_id)
    
    st.sidebar.subheader("🧠 시스템 프롬프트")
    system_prompt = st.sidebar.text_area(
        "", value=DEFAULT_SYSTEM_PROMPT, height=160, label_visibility="collapsed"
    )
    
    st.sidebar.subheader("🎛️ 생성 옵션")
    max_tokens = st.sidebar.slider("출력 최대 토큰 수", 100, 4000, 2048, 100)
    temperature = st.sidebar.slider("Temperature", 0.0, 1.0, 0.6, 0.1)
    top_p = st.sidebar.slider("Top-P", 0.0, 1.0, 0.9, 0.05)
    num_kb_docs = st.sidebar.slider("KB 검색 결과 수", 1, 10, 5, 1)
    show_topcards = st.sidebar.checkbox("🔎 유사도 Top 카드 표시", value=True)
    
    if st.sidebar.button("🧹 대화 초기화"):
        st.session_state.clear()
        st.rerun()
    
    # 상단 헤더
    st.markdown(
        f"""
        <div style="border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px 14px;margin-bottom:10px;">
          <div style="font-size:12px;opacity:.8">Online • ETEVERS Bedrock Nova Pro</div>
          <div style="font-weight:800;font-size:20px;">ETEVERS Bedrock-Nova Pro 챗봇</div>
          <div style="font-size:11px;opacity:.7">build: {APP_VERSION}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )
    
    # 대화 기록 초기화
    if "messages" not in st.session_state:
        st.session_state.messages = []
    
    # 대화 기록 표시
    for message in st.session_state.messages:
        avatar = USER_AVATAR if message["role"] == "user" else ASSISTANT_AVATAR
        with st.chat_message(message["role"], avatar=avatar):
            st.markdown(message["content"], unsafe_allow_html=True)
    
    # 사용자 입력 처리
    prompt = st.chat_input("")
    
    if prompt and not kb_id:
        st.warning("Knowledge Base ID가 설정되지 않았습니다. 좌측에서 KB ID를 입력하세요.")
        return
    
    if prompt and kb_id:
        # 사용자 메시지 표시
        with st.chat_message("user", avatar=USER_AVATAR):
            st.markdown(prompt)
        st.session_state.messages.append({"role": "user", "content": prompt})
        
        # KB 검색
        with st.spinner("KB에서 관련 정보를 검색하고 있어요…"):
            context, reranked, meta = query_kb(prompt, kb_id, num_kb_docs)
        
        # 유사도 카드 표시 (옵션)
        if show_topcards:
            logging.info(f"[UI_DEBUG] Calling render_reranker_section with {len(reranked) if reranked else 0} items")
            render_reranker_section(reranked, meta)
        
        # KB 미히트 시 차단
        if meta.get("retrieved", 0) == 0:
            with st.chat_message("assistant", avatar=ASSISTANT_AVATAR):
                st.warning("🔒 KB에서 검색할 수 없어 답변할 수 없습니다.")
            st.session_state.messages.append({"role": "assistant", "content": "KB 미히트로 차단"})
            st.stop()
        
        # 최종 프롬프트 구성
        final_system = system_prompt.strip() or DEFAULT_SYSTEM_PROMPT
        full_prompt = compose_prompt(final_system, context or "", prompt)
        call_messages = st.session_state.messages + [{"role": "user", "content": full_prompt}]
        
        # Bedrock 호출
        with st.chat_message("assistant", avatar=ASSISTANT_AVATAR):
            waiting = st.empty()
            waiting.markdown("⏳ **답변 생성 중…**")
            
            response = invoke_nova_pro(
                call_messages,
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
            )
            
            reply, gr_blocked = safe_unwrap_response(response)
            waiting.empty()
            
            reply = mask_possible_pii(reply)
            
            # Guardrail 차단 시 세션 초기화
            if gr_blocked:
                st.warning(reply)
                st.session_state.clear()
                st.stop()
            else:
                st.markdown(reply)
        
        # 정상 응답만 세션에 저장
        st.session_state.messages.append({"role": "assistant", "content": reply})
    
    # 하단 팁
    st.markdown(
        "<div style='position:sticky;bottom:0;border-top:1px solid rgba(255,255,255,.12);padding:10px 8px;margin-top:8px;font-size:12px;opacity:.8;'>"
        "<span style='font-family:ui-monospace;'>Tip</span> Shift+Enter 로 줄바꿈 • 좌측 설정창에서 옵션 조절</div>",
        unsafe_allow_html=True,
    )


if __name__ == "__main__":
    main()