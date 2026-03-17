output "db_instance_endpoint" {
  description = "The connection endpoint for the database"
  value       = aws_db_instance.postgres.endpoint
}

output "karpenter_node_role_arn" {
  description = "ARN of the KarpenterNodeRole (EC2 instance role)"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_controller_role_arn" {
  description = "⭐ Annotate karpenter SA with this ARN: eks.amazonaws.com/role-arn"
  value       = aws_iam_role.karpenter_controller.arn
}

output "db_instance_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.postgres.address
}

output "db_instance_port" {
  description = "The port of the RDS instance"
  value       = aws_db_instance.postgres.port
}

output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.postgres.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.postgres.arn
}

output "db_security_group_id" {
  description = "The security group ID for the database"
  value       = aws_security_group.postgres.id
}

output "db_credentials_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_subnet_group_name" {
  description = "The DB subnet group name"
  value       = aws_db_subnet_group.postgres.name
}

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}
