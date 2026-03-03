output "vpc_id" { value = module.network.vpc_id }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "nat_gateway_id" { value = module.network.nat_gateway_id }

output "app_sg_id" { value = aws_security_group.app.id }

output "rds_endpoint" { value = module.rds.endpoint }
output "rds_port" { value = module.rds.port }