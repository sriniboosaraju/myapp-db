# -------------------------------------------------------------------
# Shared variables (mirrored from parent infra)
# -------------------------------------------------------------------

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "myapp-db"
}

variable "environment" {
  description = "Environment name (dev, qa, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

# -------------------------------------------------------------------
# EC2-specific variables
# -------------------------------------------------------------------

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami" {
  description = "Custom AMI ID. Defaults to latest Amazon Linux 2023 when left empty."
  type        = string
  default     = ""
}

variable "ec2_subnet_id" {
  description = "Subnet ID for the EC2 instance. Defaults to first private subnet when left empty."
  type        = string
  default     = ""
}

variable "ec2_key_name" {
  description = "Name of an existing EC2 key pair. Leave empty to disable key-based SSH."
  type        = string
  default     = ""
}

variable "ec2_ssh_cidr" {
  description = "CIDR block allowed to reach port 22. Leave empty to disable the SSH ingress rule."
  type        = string
  default     = ""
}

variable "ec2_root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "ec2_associate_public_ip" {
  description = "Whether to associate a public IP with the EC2 instance"
  type        = bool
  default     = false
}

variable "ec2_create_eip" {
  description = "Whether to allocate and associate an Elastic IP (only used when ec2_associate_public_ip is true)"
  type        = bool
  default     = false
}

variable "ec2_extra_security_group_ids" {
  description = "Additional security group IDs to attach to the EC2 instance"
  type        = list(string)
  default     = []
}
