output "security_group_id" {
  value = aws_security_group.cluster.id
}

output "kafka_private_ip" {
  value = aws_instance.kafka.private_ip
}

output "debezium_private_ip" {
  value = aws_instance.debezium.private_ip
}

output "spare_private_ip" {
  value = aws_instance.spare.private_ip
}