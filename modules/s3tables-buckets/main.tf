resource "aws_s3tables_table_bucket" "this" {
  for_each = toset(var.table_bucket_names)

  name = each.value

  tags = merge(var.tags, {
    Name    = each.value
    Project = var.project_name
  })
}

# Optional namespaces for each table bucket
resource "aws_s3tables_namespace" "ns" {
  for_each = {
    for pair in setproduct(var.table_bucket_names, var.namespaces) :
    "${pair[0]}::${pair[1]}" => { bucket = pair[0], ns = pair[1] }
    if length(var.namespaces) > 0
  }

  table_bucket_arn = aws_s3tables_table_bucket.this[each.value.bucket].arn
  namespace        = each.value.ns
}