variable "aws_region" { type = string }
variable "aws_profile" { type = string }

variable "project_name" { type = string }
variable "vpc_cidr" { type = string }

variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }

variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_family" {type=string}
    