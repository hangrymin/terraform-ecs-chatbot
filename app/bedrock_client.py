# -*- coding: utf-8 -*-
"""
bedrock_client.py

이 모듈은 AWS Bedrock 기반 챗봇의 핵심 비즈니스 로직을 담당합니다.

주요 기능:
1. AWS Bedrock 클라이언트 관리 (Nova Pro, Knowledge Base, Rerank)
2. Knowledge Base 검색 및 문서 재정렬 (Rerank)
3. 개인정보 보호 및 민감정보 필터링 (PII Masking, Guardrail)
4. 대화 히스토리 관리 및 정리
5. Nova Pro 모델 호출 및 응답 처리

아키텍처:
- Nova Pro (LLM): us-east-1 리전에서 호출
- Knowledge Base: ap-northeast-2 리전 (데이터 지역성)
- Rerank: ap-northeast-1 리전 (서비스 가용성)
- SSM Parameter Store: ap-northeast-2 리전 (설정 관리)
"""

import boto3
import json
import re
import logging
from functools import lru_cache
from typing import Optional, List, Tuple, Dict, Any
from botocore.exceptions import ClientError

# =============================================================================
# 설정 상수
# =============================================================================

# AWS 리전 설정 - 각 서비스별 최적 리전 사용
BEDROCK_RUNTIME_REGION = "us-east-1"      # Nova Pro + Guardrail (모델 가용성)
BEDROCK_RERANK_REGION = "ap-northeast-1"   # Rerank (서비스 가용성)
BEDROCK_KB_REGION = "ap-northeast-2"       # Knowledge Base (데이터 지역성)
SSM_REGION = "ap-northeast-2"              # SSM Parameter Store (설정 관리)

# 모델 식별자
NOVA_PRO_MODEL_ID = "amazon.nova-pro-v1:0"  # Amazon Nova Pro 모델 ID
RERANK_MODEL_ARN = "arn:aws:bedrock:ap-northeast-1::foundation-model/amazon.rerank-v1:0"  # Rerank 모델 ARN

# 사용자 메시지
BLOCK_NOTICE = "개인정보/부적절한 표현에 대한 요청은 답변 드릴 수 없습니다."


# =============================================================================
# AWS 클라이언트 팩토리 함수들
# =============================================================================

@lru_cache(maxsize=1)
def get_bedrock_runtime():
    """
    Bedrock Runtime 클라이언트 생성 (Nova Pro 모델 호출용)
    
    Returns:
        boto3.client: us-east-1 리전의 bedrock-runtime 클라이언트
        
    Note:
        - LRU 캐시로 클라이언트 재사용 (성능 최적화)
        - Nova Pro 모델과 Guardrail은 us-east-1에서만 사용 가능
    """
    return boto3.client("bedrock-runtime", region_name=BEDROCK_RUNTIME_REGION)


@lru_cache(maxsize=1)
def get_bedrock_kb():
    """
    Bedrock Agent Runtime 클라이언트 생성 (Knowledge Base 검색용)
    
    Returns:
        boto3.client: ap-northeast-2 리전의 bedrock-agent-runtime 클라이언트
        
    Note:
        - Knowledge Base는 데이터 지역성을 위해 ap-northeast-2 사용
        - 벡터 검색 및 문서 검색 기능 제공
    """
    return boto3.client("bedrock-agent-runtime", region_name=BEDROCK_KB_REGION)


@lru_cache(maxsize=1)
def get_bedrock_rerank():
    """
    Bedrock Agent Runtime 클라이언트 생성 (Rerank 처리용)
    
    Returns:
        boto3.client: ap-northeast-1 리전의 bedrock-agent-runtime 클라이언트
        
    Note:
        - Rerank 서비스는 ap-northeast-1에서 제공
        - 검색된 문서들의 관련성 점수를 재계산하여 순서 최적화
    """
    return boto3.client("bedrock-agent-runtime", region_name=BEDROCK_RERANK_REGION)


@lru_cache(maxsize=8)
def get_ssm(region: str = SSM_REGION):
    """
    SSM Parameter Store 클라이언트 생성
    
    Args:
        region: AWS 리전 (기본값: ap-northeast-2)
        
    Returns:
        boto3.client: 지정된 리전의 SSM 클라이언트
        
    Note:
        - 설정값들(KB ID, Guardrail 정보)을 중앙 관리
        - 최대 8개 리전별 클라이언트 캐시 지원
    """
    return boto3.client("ssm", region_name=region)


# =============================================================================
# SSM Parameter Store 관련 함수들
# =============================================================================

def get_kb_id_from_ssm(param: str = "/chatbot/bedrock/kb_id") -> str:
    """
    SSM Parameter Store에서 Knowledge Base ID를 조회합니다.
    
    Args:
        param: SSM 파라미터 경로 (기본값: /chatbot/bedrock/kb_id)
        
    Returns:
        str: Knowledge Base ID 또는 빈 문자열 (실패 시)
        
    Note:
        - Terraform에서 자동으로 생성된 KB ID를 런타임에 조회
        - 실패 시 빈 문자열 반환하여 UI에서 수동 입력 유도
    """
    try:
        ssm = get_ssm()
        return ssm.get_parameter(Name=param)["Parameter"]["Value"]
    except Exception as e:
        logging.warning(f"SSM Parameter 로드 실패: {e}")
        return ""


def get_guardrail_from_ssm(prefix: str = "/chatbot/guardrail") -> Optional[Dict[str, str]]:
    """
    SSM Parameter Store에서 Guardrail 설정을 조회합니다.
    
    Args:
        prefix: SSM 파라미터 접두사 (기본값: /chatbot/guardrail)
        
    Returns:
        Optional[Dict[str, str]]: Guardrail 설정 딕셔너리 또는 None
        - id: Guardrail ID
        - version: Guardrail 버전
        - region: Guardrail 리전
        
    Note:
        - Terraform Stack3에서 생성된 Guardrail 정보를 조회
        - Guardrail은 us-east-1 리전에 배포되므로 해당 리전에서 조회
        - 실패 시 None 반환하여 Guardrail 없이 동작
    """
    try:
        ssm = get_ssm(region="us-east-1")  # Guardrail 파라미터는 us-east-1에 존재
        gr_id = ssm.get_parameter(Name=f"{prefix}/id")["Parameter"]["Value"]
        gr_ver = ssm.get_parameter(Name=f"{prefix}/version")["Parameter"]["Value"]
        gr_rg = ssm.get_parameter(Name=f"{prefix}/region")["Parameter"]["Value"]
        return {"id": gr_id, "version": gr_ver, "region": gr_rg}
    except Exception as e:
        logging.warning(f"Guardrail SSM 로드 실패: {e}")
        return None


# =============================================================================
# 프롬프트 구성 함수
# =============================================================================

def compose_prompt(system: str, context: str, question: str) -> str:
    """
    시스템 프롬프트, KB 컨텍스트, 사용자 질문을 조합하여 최종 프롬프트를 생성합니다.
    
    Args:
        system: 시스템 지침 (역할 정의, 응답 스타일 등)
        context: Knowledge Base에서 검색된 관련 문서 내용
        question: 사용자의 실제 질문
        
    Returns:
        str: 구조화된 최종 프롬프트
        
    Note:
        - RAG(Retrieval-Augmented Generation) 패턴 구현
        - 명확한 섹션 구분으로 모델의 이해도 향상
        - 시스템 지침이 없으면 해당 섹션 생략
    """
    parts = []
    if system and system.strip():
        parts.append("[시스템 지침]\n" + system.strip())
    parts.append("[배경 정보]\n" + (context or ""))
    parts.append("[질문]\n" + question)
    return "\n\n".join(parts)


# =============================================================================
# 개인정보 보호 및 민감정보 필터링
# =============================================================================

# 개인정보 탐지 정규식 패턴 (응답 마스킹용)
PII_REGEXES = [
    re.compile(r"\b\d{6}-[1-4]\d{6}\b"),                    # 주민번호 (YYMMDD-1234567 형태)
    re.compile(r"01[016789]-?\d{3,4}-?\d{4}"),              # 휴대폰번호 (010, 011, 016, 017, 018, 019)
    re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),  # 이메일 주소
    re.compile(r"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"),     # 신용카드번호 (16자리)
]


def mask_possible_pii(text: str) -> str:
    """
    응답 텍스트에서 개인정보를 마스킹 처리합니다.
    
    Args:
        text: 마스킹할 텍스트
        
    Returns:
        str: 개인정보가 마스킹된 텍스트
        
    Note:
        - 모델 응답에서 의도치 않게 포함된 개인정보 보호
        - 정규식 패턴과 일치하는 부분을 '[민감정보-마스킹]'으로 대체
        - 최종 사용자 출력 전 마지막 보안 계층
    """
    if not text:
        return text
    
    masked = text
    for regex in PII_REGEXES:
        masked = regex.sub("[민감정보-마스킹]", masked)
    return masked


# =============================================================================
# 대화 히스토리 관리
# =============================================================================

def clean_messages(messages: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """
    대화 히스토리를 정리하여 Bedrock 호출에 적합한 형태로 변환합니다.
    
    Args:
        messages: 원본 메시지 리스트 [{'role': str, 'content': str}, ...]
        
    Returns:
        List[Dict[str, str]]: 정리된 메시지 리스트
        
    처리 과정:
        1. system 역할 메시지 제거 (Bedrock converse API 미지원)
        2. 차단 안내 assistant 메시지 제거 (불필요한 컨텍스트 제거)
        3. user 메시지로 시작하도록 보장 (대화 구조 정규화)
        
    Note:
        - 기존 sanitize_history()와 _ensure_user_starts() 함수 통합
        - 메모리 효율성과 컨텍스트 품질 향상
    """
    cleaned = []
    
    for msg in messages:
        role = msg.get("role")
        content = msg.get("content", "")
        
        # system 역할 제거 (Bedrock converse API 미지원)
        if role == "system":
            continue
        
        # 차단 안내 assistant 메시지 제거 (이전 세션의 잔여물)
        if role == "assistant" and BLOCK_NOTICE in content:
            continue
        
        cleaned.append({"role": role, "content": content})
    
    # 대화는 반드시 user 메시지로 시작해야 함
    while cleaned and cleaned[0].get("role") != "user":
        cleaned.pop(0)
    
    return cleaned


# =============================================================================
# Knowledge Base 검색 및 문서 재정렬
# =============================================================================

def rerank_documents(query: str, documents: List[str], top_n: int = 3) -> List[Tuple[str, float]]:
    """
    AWS Bedrock Rerank 모델을 사용하여 검색된 문서들을 관련성 순으로 재정렬합니다.
    
    Args:
        query: 사용자 질문 (재정렬 기준)
        documents: 재정렬할 문서 리스트
        top_n: 반환할 상위 문서 수 (기본값: 3)
        
    Returns:
        List[Tuple[str, float]]: (문서 내용, 관련성 점수) 튜플 리스트
        
    처리 과정:
        1. Bedrock Rerank API 호출 (ap-northeast-1 리전)
        2. 각 문서에 대한 관련성 점수 계산
        3. 점수 기준 내림차순 정렬
        4. 실패 시 원본 순서 유지 (Graceful Degradation)
        
    Note:
        - RAG 시스템의 핵심 구성요소
        - 벡터 검색 결과의 정확도 향상
        - 실패해도 서비스 중단 없이 동작
    """
    if not documents:
        return []
    
    try:
        client = get_bedrock_rerank()
        response = client.rerank(
            queries=[{"type": "TEXT", "textQuery": {"text": query}}],
            sources=[{
                "type": "INLINE",
                "inlineDocumentSource": {"type": "TEXT", "textDocument": {"text": doc}}
            } for doc in documents],
            rerankingConfiguration={
                "type": "BEDROCK_RERANKING_MODEL",
                "bedrockRerankingConfiguration": {
                    "modelConfiguration": {"modelArn": RERANK_MODEL_ARN},
                    "numberOfResults": min(top_n, len(documents))
                }
            }
        )
        
        # API 응답에서 문서와 점수 추출
        scored = []
        for i, result in enumerate(response.get("results", [])):
            # Rerank API 응답 구조 디버깅
            logging.info(f"[RERANK_DEBUG] Result {i}: {str(result)[:200]}...")
            
            text = (
                result.get("document", {})
                .get("inlineDocument", {})
                .get("textDocument", {})
                .get("text", "")
            )
            score = result.get("relevanceScore", 0.0)
            
            logging.info(f"[RERANK_DEBUG] Extracted - text_len: {len(text)}, score: {score}, text_preview: {repr(text[:50])}")
            
            # 빈 텍스트인 경우 원본 문서에서 찾기
            if not text and i < len(documents):
                text = documents[i]
                logging.info(f"[RERANK_DEBUG] Using original document: {text[:50]}...")
            
            scored.append((text, score))
        
        # 관련성 점수 기준 내림차순 정렬
        return sorted(scored, key=lambda x: x[1], reverse=True)
    
    except Exception as e:
        # Rerank 실패 시 원본 순서 유지 (Graceful Degradation)
        logging.warning(f"Rerank 실패, 원본 순서 유지: {e}")
        fallback = [(doc, 0.0) for doc in documents[:top_n]]
        logging.info(f"[RERANK_DEBUG] Fallback documents: {len(fallback)}")
        return fallback


def query_kb(prompt: str, kb_id: str, num_docs: int = 3) -> Tuple[Optional[str], List[Tuple[str, float]], Dict[str, Any]]:
    """
    Knowledge Base에서 관련 문서를 검색하고 Rerank로 재정렬합니다.
    
    Args:
        prompt: 사용자 질문
        kb_id: Knowledge Base ID
        num_docs: 검색할 문서 수 (기본값: 3)
        
    Returns:
        Tuple containing:
        - Optional[str]: 결합된 컨텍스트 문서 (실패 시 None)
        - List[Tuple[str, float]]: (문서, 관련성점수) 리스트
        - Dict[str, Any]: 메타데이터 {'retrieved': int, 'error': str|None}
        
    처리 과정:
        1. Knowledge Base 벡터 검색 수행
        2. 검색 결과에서 텍스트 내용 추출
        3. Rerank 모델로 관련성 기준 재정렬
        4. 상위 문서들을 하나의 컨텍스트로 결합
        
    Note:
        - RAG(Retrieval-Augmented Generation)의 핵심 구현
        - Terraform Stack2에서 생성된 KB 사용
        - 검색 실패 시에도 안전하게 처리
    """
    meta = {"retrieved": 0, "error": None}
    
    try:
        # Knowledge Base 벡터 검색 수행
        client = get_bedrock_kb()
        result = client.retrieve(
            knowledgeBaseId=kb_id,
            retrievalQuery={"text": prompt},
            retrievalConfiguration={
                "vectorSearchConfiguration": {"numberOfResults": num_docs}
            },
        )
        
        hits = result.get("retrievalResults", [])
        meta["retrieved"] = len(hits)
        
        # 검색 결과에서 텍스트 내용 추출
        docs = []
        for i, hit in enumerate(hits):
            content = hit.get("content")
            logging.info(f"[DEBUG] Hit {i+1} content type: {type(content)}, content: {str(content)[:200]}...")
            
            # content 구조는 KB 설정에 따라 다를 수 있음
            if isinstance(content, dict) and "text" in content:
                text = content["text"]
                docs.append(text)
                logging.info(f"[DEBUG] Extracted text (dict): {text[:100]}...")
            elif isinstance(content, list) and content and isinstance(content[0], dict) and "text" in content[0]:
                text = content[0]["text"]
                docs.append(text)
                logging.info(f"[DEBUG] Extracted text (list): {text[:100]}...")
            else:
                logging.warning(f"[DEBUG] Unknown content structure: {content}")
        
        if not docs:
            logging.warning(f"[DEBUG] No documents extracted from {len(hits)} hits")
            return None, [], meta
        
        logging.info(f"[DEBUG] Successfully extracted {len(docs)} documents")
        
        # Rerank 모델로 관련성 기준 재정렬
        reranked = rerank_documents(prompt, docs, top_n=min(3, len(docs)))
        
        # Rerank 결과 디버깅
        logging.info(f"[DEBUG] Reranked documents: {len(reranked)}")
        for i, (doc, score) in enumerate(reranked):
            logging.info(f"[DEBUG] Reranked[{i}] score={score:.3f}, doc_type={type(doc)}, doc_len={len(doc) if doc else 0}, doc_preview={repr(doc[:50]) if doc else 'None'}")
        
        # 빈 문서 필터링 (더 관대한 조건)
        filtered_reranked = [(doc, score) for doc, score in reranked if doc is not None and str(doc).strip()]
        logging.info(f"[DEBUG] After filtering: {len(filtered_reranked)} documents")
        
        for i, (doc, score) in enumerate(filtered_reranked):
            logging.info(f"[DEBUG] Filtered doc {i+1} (score: {score:.3f}): {doc[:100]}...")
        
        # 상위 문서들을 하나의 컨텍스트로 결합
        context = "\n\n".join([doc for doc, _ in filtered_reranked])
        
        # 필터링된 결과가 비어있으면 원본 사용
        final_reranked = filtered_reranked if filtered_reranked else reranked
        logging.info(f"[DEBUG] Final reranked count: {len(final_reranked)}")
        
        return context, final_reranked, meta
        
        return context, reranked, meta
    
    except ClientError as e:
        meta["error"] = f"ClientError: {e}"
        return None, [], meta
    except Exception as e:
        meta["error"] = str(e)
        return None, [], meta


# =============================================================================
# Nova Pro 모델 호출
# =============================================================================

def invoke_nova_pro(messages: List[Dict[str, str]], *, max_tokens: int, temperature: float, top_p: float) -> Tuple[str, bool]:
    """
    Amazon Nova Pro 모델을 호출하여 응답을 생성합니다.
    
    Args:
        messages: 대화 히스토리 [{'role': str, 'content': str}, ...]
        max_tokens: 최대 생성 토큰 수
        temperature: 창의성 조절 (0.0-1.0)
        top_p: 토큰 선택 범위 조절 (0.0-1.0)
        
    Returns:
        Tuple[str, bool]: (응답 텍스트, Guardrail 차단 여부)
        
    처리 과정:
        1. 메시지 히스토리 정리 및 검증
        2. Bedrock Converse API 형식으로 변환
        3. Guardrail 설정 적용 (있는 경우)
        4. Nova Pro 모델 호출
        5. 응답 파싱 및 PII 마스킹
        
    Note:
        - us-east-1 리전에서 호출 (Nova Pro 가용 리전)
        - Guardrail과 PII 마스킹으로 이중 보안
        - 실패 시에도 안전한 오류 메시지 반환
    """
    # 1. 메시지 히스토리 정리
    messages = clean_messages(messages)
    
    # 2. Bedrock Converse API 형식으로 변환
    conv_messages = [
        {"role": msg["role"], "content": [{"text": msg["content"]}]}
        for msg in messages if msg.get("role") in ["user", "assistant"]
    ]
    
    # 3. API 호출 파라미터 구성
    kwargs = {
        "modelId": NOVA_PRO_MODEL_ID,
        "messages": conv_messages,
        "inferenceConfig": {
            "maxTokens": max_tokens,
            "temperature": temperature,
            "topP": top_p
        },
    }
    
    # 4. Guardrail 설정 적용 (Terraform Stack3에서 생성)
    guardrail = get_guardrail_from_ssm()
    if guardrail and guardrail.get("id") and guardrail.get("version"):
        # Guardrail 리전이 Nova Pro 호출 리전과 일치하는지 확인
        if guardrail.get("region") == BEDROCK_RUNTIME_REGION:
            kwargs["guardrailConfig"] = {
                "guardrailIdentifier": guardrail["id"],
                "guardrailVersion": guardrail["version"],
            }
            logging.info(f"Guardrail 적용: {guardrail['id']} v{guardrail['version']}")
        else:
            logging.warning(f"Guardrail 리전 불일치: {guardrail['region']} != {BEDROCK_RUNTIME_REGION}")
    
    # 5. Nova Pro 모델 호출
    try:
        client = get_bedrock_runtime()
        response = client.converse(**kwargs)
        
        # Guardrail 차단 여부 확인
        stop_reason = response.get("stopReason", "")
        gr_blocked = "guardrail" in stop_reason.lower()
        
        # 응답 텍스트 추출
        output = response.get("output", {}).get("message", {}).get("content", [])
        if output and isinstance(output, list) and isinstance(output[0], dict) and "text" in output[0]:
            reply = output[0]["text"]
            # PII 마스킹 적용 후 반환
            return mask_possible_pii(reply), gr_blocked
        
        # Guardrail에 의한 차단 시
        if gr_blocked:
            return "개인정보/부적절한 표현에 대한 응답은 제공되지 않습니다.", True
        
        # 기타 예외 상황
        return f"응답 실패: 모델 출력이 비어있습니다. (stopReason={stop_reason})", False
    
    except Exception as e:
        logging.error(f"Nova Pro 호출 실패: {e}")
        return f"응답 실패: {e}", False