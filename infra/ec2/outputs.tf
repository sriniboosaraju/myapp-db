# -------------------------------------------------------------------
# EC2 outputs
# -------------------------------------------------------------------

output "ec2_instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "ec2_instance_arn" {
  description = "The ARN of the EC2 instance"
  value       = aws_instance.app.arn
}

output "ec2_private_ip" {
  description = "The private IP address of the EC2 instance"
  value       = aws_instance.app.private_ip
}

output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance (if assigned)"
  value       = var.ec2_associate_public_ip ? aws_instance.app.public_ip : null
}

output "ec2_elastic_ip" {
  description = "The Elastic IP address (if created)"
  value       = var.ec2_associate_public_ip && var.ec2_create_eip ? aws_eip.ec2[0].public_ip : null
}

output "ec2_security_group_id" {
  description = "The security group ID attached to the EC2 instance"
  value       = aws_security_group.ec2.id
}

output "ec2_iam_role_arn" {
  description = "The ARN of the IAM role attached to the EC2 instance"
  value       = aws_iam_role.ec2.arn
}

output "ec2_instance_profile_name" {
  description = "The name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_ami_id" {
  description = "The AMI ID used by the EC2 instance"
  value       = aws_instance.app.ami
}
