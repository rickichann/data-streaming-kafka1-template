variable "project_name" { type = string }
variable "vpc_id"       { type = string }

variable "private_subnet_ids" {
  type = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "bastion_sg_id"{
    type = string
}