variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "myapp-db-db"
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
  description = "VPC ID where the database will be created"
  type        = string
  default     = "vpc-placeholder"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the database subnet group"
  type        = list(string)
  default     = ["subnet-placeholder1", "subnet-placeholder2"]
}

variable "app_security_group_ids" {
  description = "List of security group IDs that can access the database"
  type        = list(string)
  default     = ["sg-placeholder"]
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the default database"
  type        = string
  default     = "myapp-db_db"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres"
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster (used for Karpenter IAM)"
  type        = string
  default     = "eks-srini"
}
