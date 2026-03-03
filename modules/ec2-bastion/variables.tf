variable "project_name" { type = string }

variable "vpc_id" { type = string }

variable "public_subnet_id" {
  type = string
}

variable "allowed_ssh_cidr" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}