output "table_bucket_arns" {
  value = { for k, v in aws_s3tables_table_bucket.this : k => v.arn }
}

output "table_bucket_names" {
  value = keys(aws_s3tables_table_bucket.this)
}