variable "project_name" {
  type = string
}

variable "table_bucket_names" {
  type = list(string)
}

# Optional: create namespaces inside each table bucket
# (If you don't need namespaces yet, keep empty list)
variable "namespaces" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}