variable "project_name" { type = string }
variable "vpc_id"       { type = string }

variable "private_subnet_ids" {
  type = list(string)
}

# Access control: allow Postgres only from these SGs (app/compute SGs)
variable "allowed_sg_ids" {
  type = list(string)
}


variable "db_name"           { type = string }
variable "db_username"       { type = string }


variable "db_password" {
  type      = string
  sensitive = true
}

variable "engine_version" {
  type    = string
  default = "17.2"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "db_parameter_group_family" {
  type = string
}