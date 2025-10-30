# -*- coding: utf-8 -*-
"""
app_core.py
- 비 UI 로직: SSM/Guardrail, KB 검색, Rerank, Nova Pro 호출(converse)
- 반환 규약(절대 불변): invoke_nova_pro() -> (reply: str, gr_blocked: bool)
"""

import boto3
import json
import re
import logging
from functools import lru_cache
from typing import Optional, List, Tuple, Dict, Any
from botocore.exceptions import ClientError


@lru_cache(maxsize=1)
def get_bedrock_runtime():
    # Nova Pro (us-east-1)
    return boto3.client("bedrock-runtime", region_name="us-east-1")

@lru_cache(maxsize=1)
def get_bedrock_kb():
    # Knowledge Base (ap-northeast-2)
    return boto3.client("bedrock-agent-runtime", region_name="ap-northeast-2")

@lru_cache(maxsize=1)
def get_bedrock_rerank():
    # Rerank (ap-northeast-1)
    return boto3.client("bedrock-agent-runtime", region_name="ap-northeast-1")

@lru_cache(maxsize=8)
def get_ssm(region: str):
    return boto3.client("ssm", region_name=region)

def get_kb_id_from_ssm(param: str = "/chatbot/bedrock/kb_id", region: str = "ap-northeast-2") -> str:
    try:
        ssm = get_ssm(region)
        return ssm.get_parameter(Name=param)["Parameter"]["Value"]
    except Exception as e:
        logging.warning(f"[SSM Parameter 로드 실패] {e}")
        return ""

def get_guardrail_from_ssm(prefix: str = "/chatbot/guardrail", region: str = "us-east-1") -> Optional[Dict[str, str]]:
    """Guardrail ID/Version/Region 읽기 (없으면 None)"""
    try:
        ssm = get_ssm(region)
        gr_id = ssm.get_parameter(Name=f"{prefix}/id")["Parameter"]["Value"]
        gr_ver = ssm.get_parameter(Name=f"{prefix}/version")["Parameter"]["Value"]
        gr_rg = ssm.get_parameter(Name=f"{prefix}/region")["Parameter"]["Value"]
        return {"id": gr_id, "version": gr_ver, "region": gr_rg}
    except Exception as e:
        logging.warning(f"[Guardrail SSM 로드 실패] {e}")
        return None

def compose_prompt(system: str, context: str, question: str) -> str:
    parts = []
    if system and system.strip():
        parts.append("[시스템 지침]\n" + system.strip())
    parts.append("[배경 정보]\n" + (context or ""))
    parts.append("[질문]\n" + question)
    return "\n\n".join(parts)

PII_REGEXES = [
    re.compile(r"\b\d{6}-\d{7}\b"),  # 주민번호
    re.compile(r"(?:01[016789]|02|0[3-6][1-5]|0[7-9][0-9])[-.\s]?\d{3,4}[-.\s]?\d{4}"),  # 전화번호
    re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),  # 이메일
    re.compile(r"\b(?:\d[ -]*?){13,16}\b"),  # 카드번호 유사
]
PROFANITY_RE = re.compile(r"(시\s*발|씨\s*발|개\s*새\s*끼|병\s*신|좆|fuck|shit)", re.IGNORECASE)
BLOCK_NOTICE = "개인정보/부적절한 표현에 대한 요청은 답변 드릴 수 없습니다."

def _is_sensitive_text(s: str) -> bool:
    if PROFANITY_RE.search(s):
        return True
    for rx in PII_REGEXES:
        if rx.search(s):
            return True
    return False

def soft_guardrail_check(user_text: str) -> Tuple[bool, str]:
    """민감/비속어 탐지 시 차단 안내"""
    if _is_sensitive_text(user_text or ""):
        return True, "개인정보/부적절한 표현에 대한 요청은 답변 드릴 수 없습니다."
    return False, ""

def mask_possible_pii(text: str) -> str:
    if not text:
        return text
    masked = text
    for rx in PII_REGEXES:
        masked = rx.sub("[민감정보-마스킹]", masked)
    return masked

def sanitize_history(raw_messages: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """
    과거 히스토리에서 금칙 user/차단 안내 assistant 등을 제거.
    system 역할은 Bedrock converse 미지원 → 제거.
    """
    cleaned: List[Dict[str, str]] = []
    for m in raw_messages:
        role = m.get("role")
        content = m.get("content", "")
        if role == "system":
            continue
        if role == "user" and _is_sensitive_text(content):
            continue
        if role == "assistant" and BLOCK_NOTICE in content:
            continue
        cleaned.append({"role": role, "content": content})
    return cleaned

def _ensure_user_starts(messages: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """대화는 반드시 user로 시작해야 함."""
    i = 0
    while i < len(messages) and messages[i].get("role") != "user":
        i += 1
    return messages[i:] if i < len(messages) else []

def aws_rerank_documents(query: str, documents: List[str], top_n: int = 3, model_arn: Optional[str] = None) -> List[Tuple[str, float]]:
    """Amazon Bedrock Rerank(API, ap-northeast-1)로 재정렬 (가능하면 사용)"""
    if not documents:
        return []
    if model_arn is None:
        model_arn = "arn:aws:bedrock:ap-northeast-1::foundation-model/amazon.rerank-v1:0"

    client = get_bedrock_rerank()
    resp = client.rerank(
        queries=[{"type": "TEXT", "textQuery": {"text": query}}],
        sources=[{
            "type": "INLINE",
            "inlineDocumentSource": {"type": "TEXT", "textDocument": {"text": doc}}
        } for doc in documents],
        rerankingConfiguration={
            "type": "BEDROCK_RERANKING_MODEL",
            "bedrockRerankingConfiguration": {
                "modelConfiguration": {"modelArn": model_arn},
                "numberOfResults": min(top_n, len(documents))
            }
        }
    )

    req_id = (resp.get("ResponseMetadata") or {}).get("RequestId")
    logging.info(f"[RERANK_OK] region=ap-northeast-1 model={model_arn} requestId={req_id} "
                 f"topK={min(top_n, len(documents))} results={len(resp.get('results', []))}")

    scored: List[Tuple[str, float]] = []
    for r in resp.get("results", []):
        text = (
            r.get("document", {})
             .get("inlineDocument", {})
             .get("textDocument", {})
             .get("text", "")
        )
        try:
            idx = documents.index(text)
        except ValueError:
            idx = 0
        scored.append((documents[idx], r.get("relevanceScore", 0.0)))

    scored.sort(key=lambda x: x[1], reverse=True)
    return scored

def query_kb(prompt: str, kb_id: str, num_docs: int = 3) -> Tuple[Optional[str], List[Tuple[str, float]], Dict[str, Any]]:
    """KB 검색 → AWS Rerank → (문서/점수/메타)"""
    meta: Dict[str, Any] = {"retrieved": 0, "error": None}
    try:
        kb = get_bedrock_kb()
        result = kb.retrieve(
            knowledgeBaseId=kb_id,
            retrievalQuery={"text": prompt},
            retrievalConfiguration={"vectorSearchConfiguration": {"numberOfResults": num_docs}},
        )
        hits = result.get("retrievalResults", []) or []
        meta["retrieved"] = len(hits)

        docs: List[str] = []
        for h in hits:
            c = h.get("content")
            if isinstance(c, dict) and "text" in c:
                docs.append(c["text"])
            elif isinstance(c, list) and c and isinstance(c[0], dict) and "text" in c[0]:
                docs.append(c[0]["text"])

        if not docs:
            return None, [], meta

        try:
            reranked = aws_rerank_documents(prompt, docs, top_n=min(3, len(docs))) or []
        except Exception as e:
            logging.warning(f"[AWS RERANK 실패] {e}")
            # 로컬 Fallback 제거(일관성 유지). 실패 시 원본 그대로.
            reranked = [(d, 0.0) for d in docs[:min(3, len(docs))]]

        return "\n\n".join([doc for doc, _ in reranked]), reranked, meta
    except ClientError as e:
        meta["error"] = f"ClientError: {e}"
        return None, [], meta
    except Exception as e:
        meta["error"] = str(e)
        return None, [], meta

def invoke_nova_pro(messages: List[Dict[str, str]], *, max_tokens: int, temperature: float, top_p: float) -> Tuple[str, bool]:
    """
    Bedrock converse 호출.
    반환(절대 불변): (reply_text, gr_blocked)
    """
    # 1) 히스토리 정리
    messages = sanitize_history(messages)
    messages = _ensure_user_starts(messages)

    # 2) 메시지 포맷
    conv_messages: List[Dict[str, Any]] = [
        {"role": m["role"], "content": [{"text": m["content"]}]}
        for m in messages if m.get("role") in ["user", "assistant"]
    ]

    kwargs: Dict[str, Any] = {
        "modelId": "amazon.nova-pro-v1:0",
        "messages": conv_messages,
        "inferenceConfig": {"maxTokens": max_tokens, "temperature": temperature, "topP": top_p},
    }

    # 3) Guardrail 적용(SSM)
    gr = get_guardrail_from_ssm()
    if gr and gr.get("id") and gr.get("version"):
        # Nova Pro는 us-east-1에서 호출 → region 불일치시 스킵
        if gr.get("region") and gr["region"] != "us-east-1":
            logging.warning(f"[GUARDRAIL_SKIPPED_REGION] guardrail_region={gr['region']} runtime=us-east-1")
        else:
            kwargs["guardrailConfig"] = {
                "guardrailIdentifier": gr["id"],
                "guardrailVersion": gr["version"],
            }
            logging.info(f"[GUARDRAIL_APPLY] id={gr['id']} ver={gr['version']}")

    # 4) 호출
    try:
        client = get_bedrock_runtime()
        resp = client.converse(**kwargs)

        # guardrail 개입 여부 추정
        stop_reason = resp.get("stopReason")
        gr_blocked = bool(stop_reason and "guardrail" in stop_reason.lower())

        # 정상 텍스트 파싱
        out = resp.get("output", {}).get("message", {}).get("content", [])
        if out and isinstance(out, list) and isinstance(out[0], dict) and "text" in out[0]:
            reply = out[0]["text"]
            return mask_possible_pii(reply), gr_blocked

        # 텍스트가 비어있고 guardrail 개입이면 차단 문구로 반환
        if gr_blocked:
            return "개인정보/부적절한 표현에 대한 응답은 제공되지 않습니다.", True

        # 그 외 예외 케이스
        return f"응답 실패: 모델 출력이 비어있습니다. (stopReason={stop_reason})", False

    except Exception as e:
        return f"응답 실패: {e}", False
