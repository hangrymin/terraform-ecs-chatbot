# 다른 모듈이나 상위 루트 모듈에서 참조
# S3 버킷의 ID 출력
output "bucket_name" {
  value = aws_s3_bucket.docs.id
}

# 생성된 S3 버킷의 ARN 출력
output "arn" {
  value = aws_s3_bucket.docs.arn
}
