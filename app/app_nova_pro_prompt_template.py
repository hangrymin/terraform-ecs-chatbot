# -*- coding: utf-8 -*-
"""
Streamlit UI
- 기능 로직은 app_core.py에서 import
- invoke_nova_pro는 무조건 (str,bool) 튜플을 반환 (UI 쪽은 안전 언랩도 추가)
- [변경점] 가드레일 차단 시 자동 초기화(세션 클리어) 로직 유지
- [변경점] 로컬/컨테이너/EC2 모두에서 안전한 로깅 디렉터리 자동 선택
"""

import os
import logging
from pathlib import Path
import streamlit as st

from app_core import (
    compose_prompt,
    get_kb_id_from_ssm,
    soft_guardrail_check,
    mask_possible_pii,
    query_kb,
    invoke_nova_pro,
)

APP_VERSION = "ui-override-hf3-2025-11-24-logdir-portable"

def _unwrap_two(out):
    try:
        if isinstance(out, tuple):
            a = out[0] if len(out) > 0 else ""
            b = bool(out[1]) if len(out) > 1 else False
            return str(a), b
        # 문자열/기타도 안전 처리
        return str(out), False
    except Exception as e:
        return f"응답 실패(unwrap): {e}", False

# 페이지 설정
st.set_page_config(
    page_title="ETEVERS Bedrock Nova Pro 챗봇",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# 로깅 설정
def _pick_log_dir() -> Path:
    env_dir = os.getenv("LOG_DIR")
    if env_dir:
        p = Path(env_dir)
        p.mkdir(parents=True, exist_ok=True)
        return p

    p = Path("/var/log/app")
    try:
        p.mkdir(parents=True, exist_ok=True)
        return p
    except Exception:
        pass

    p = Path.cwd() / "logs"
    p.mkdir(parents=True, exist_ok=True)
    return p

LOG_DIR = str(_pick_log_dir())
LOG_FILE = f"{LOG_DIR}/streamlit_chatbot.log"

logger = logging.getLogger()
logger.setLevel(logging.INFO)

for h in list(logger.handlers):
    logger.removeHandler(h)

fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")

try:
    fh = logging.FileHandler(LOG_FILE)
    fh.setFormatter(fmt)
    logger.addHandler(fh)
except Exception as e:
    logging.warning(f"[LOG_FILE_DISABLED] {e}")

sh = logging.StreamHandler()
sh.setFormatter(fmt)
logger.addHandler(sh)

logging.info(f"[BOOT] Streamlit UI started version={APP_VERSION} log_dir={LOG_DIR}")

# 기본 시스템 프롬프트
DEFAULT_SYSTEM_PROMPT = (
    "당신은 AWS 소개 및 제안, 금융분야 클라우드컴퓨팅서비스 전문가입니다. "
    "질문자의 배경지식이 완벽하지 않을 수 있음을 고려해, 쉬운 용어로 단계적으로 설명하되, "
    "필요한 경우 구체 예시와 권장 아키텍처, 고 링크(서비스명/프로그램명만)를 제시하세요. "
    "모호할 때는 필요한 사실을 먼저 확인하는 질문을 1~2개 던진 뒤 답하세요. "
    "허용된 지식베이스 문서에 근거해 답하며, 추정이 필요할 때는 '추정'임을 명확히 표기하세요."
)

# 사이드바
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

# 대화 기록 표시
ASSISTANT_AVATAR = "🤖"
USER_AVATAR = "🧑"

if "messages" not in st.session_state:
    st.session_state.messages = []

for m in st.session_state.messages:
    with st.chat_message(m["role"], avatar=(USER_AVATAR if m["role"] == "user" else ASSISTANT_AVATAR)):
        st.markdown(m["content"], unsafe_allow_html=True)

# Reranker 카드
def render_reranker_section(reranked, meta):
    st.markdown("### 🔎 Reranker 결과")
    st.caption(f"검색 결과: **{meta.get('retrieved', 0)}건**")
    if meta.get("error"):
        st.warning(f"KB 검색 오류: {meta['error']}")
        return
    if reranked:
        cols = st.columns(min(3, len(reranked)))
        for i, (doc, score) in enumerate(reranked):
            with cols[i % len(cols)]:
                st.caption(f"Top {i+1} • 유사도 {score:.3f}")
                st.progress(min(max(score, 0.0), 1.0))
                with st.expander("본문 보기"):
                    st.write(doc)
    else:
        st.info("관련 문서를 찾지 못했습니다. KB ID/리전, S3 인덱싱, ‘KB 검색 결과 수’를 확인하세요.")

# 입력 처리
prompt = st.chat_input("")
if prompt and not kb_id:
    st.warning("Knowledge Base ID가 설정되지 않았습니다. 좌측에서 KB ID를 입력하세요.")

if prompt and kb_id:
    # 0) 소프트 가드레일
    blocked, msg = soft_guardrail_check(prompt)
    if blocked:
        with st.chat_message("assistant", avatar=ASSISTANT_AVATAR):
            st.warning(msg)
        # 🔒 차단 즉시 세션 리셋 → 다음 질문은 깨끗한 상태
        st.session_state.clear()
        st.stop()

    # 1) 사용자 메시지
    with st.chat_message("user", avatar=USER_AVATAR):
        st.markdown(prompt)
    st.session_state.messages.append({"role": "user", "content": prompt})

    # 2) KB 검색 + 리랭크
    with st.spinner("KB에서 관련 정보를 검색하고 있어요…"):
        context, reranked, meta = query_kb(prompt, kb_id, num_kb_docs)

    # 3) (옵션) 유사도 Top 카드
    if show_topcards:
        render_reranker_section(reranked, meta)

    # 4) KB 미히트면 차단 (현행 유지)
    if meta.get("retrieved", 0) == 0:
        with st.chat_message("assistant", avatar=ASSISTANT_AVATAR):
            st.warning("🔒 KB에서 검색할 수 없어 답변할 수 없습니다.")
        st.session_state.messages.append({"role": "assistant", "content": "KB 미히트로 차단"})
        st.stop()

    # 5) 시스템 프롬프트 + KB 컨텍스트 포함 최종 프롬프트
    final_sys = (system_prompt or "").strip() or DEFAULT_SYSTEM_PROMPT
    full_prompt = compose_prompt(final_sys, context or "", prompt)
    call_messages = st.session_state.messages + [{"role": "user", "content": full_prompt}]

    # 6) Bedrock 호출 — 안전 언랩으로 2-튜플 보장
    with st.chat_message("assistant", avatar=ASSISTANT_AVATAR):
        waiting = st.empty()
        waiting.markdown("⏳ **답변 생성 중…**")

        reply, gr_blocked = _unwrap_two(invoke_nova_pro(
            call_messages,
            max_tokens=max_tokens,
            temperature=temperature,
            top_p=top_p,
        ))

        waiting.empty()
        reply = mask_possible_pii(reply)

        # Guardrail 개입 시에도 세션 자동 초기화
        if gr_blocked:
            st.warning(reply)  # 차단 안내 표시
            st.session_state.clear()
            st.stop()
        else:
            st.markdown(reply)

    # 7) 세션 저장 (정상 응답만 저장)
    st.session_state.messages.append({"role": "assistant", "content": reply})

# Tip
st.markdown(
    "<div style='position:sticky;bottom:0;border-top:1px solid rgba(255,255,255,.12);padding:10px 8px;margin-top:8px;font-size:12px;opacity:.8;'>"
    "<span style='font-family:ui-monospace;'>Tip</span> Shift+Enter 로 줄바꿈 • 좌측 설정창에서 옵션 조절</div>",
    unsafe_allow_html=True,
)
