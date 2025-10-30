CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS bedrock_integration;

DO $$ 
BEGIN 
  CREATE ROLE bedrock_user LOGIN; 
EXCEPTION 
  WHEN duplicate_object THEN 
    RAISE NOTICE 'Role already exists'; 
END 
$$;

GRANT ALL ON SCHEMA bedrock_integration TO bedrock_user;

SET SESSION AUTHORIZATION bedrock_user;

CREATE TABLE IF NOT EXISTS bedrock_integration.bedrock_kb (
    id uuid PRIMARY KEY,
    embedding vector(1024),
    chunks text,
    metadata json
);

-- 벡터 인덱스
CREATE INDEX IF NOT EXISTS bedrock_kb_embedding_idx 
  ON bedrock_integration.bedrock_kb 
  USING hnsw (embedding vector_cosine_ops);

-- chunks 컬럼용 GIN 인덱스 (Bedrock 필수)
CREATE INDEX IF NOT EXISTS bedrock_kb_chunks_idx
ON bedrock_integration.bedrock_kb
USING gin (to_tsvector('simple', chunks));