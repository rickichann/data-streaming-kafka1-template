output "vpc_id" { value = aws_vpc.this.id }

output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }

output "private_route_table_id" { value = aws_route_table.private.id }

output "s3_endpoint_id" { value = aws_vpc_endpoint.s3.id }
output "nat_gateway_id" { value = aws_nat_gateway.nat.id }