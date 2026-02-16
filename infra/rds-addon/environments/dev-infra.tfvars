environment = "dev-infra"
aws_region  = "us-east-1"

# Network configuration - EKS Srini Cluster VPC
vpc_id             = "vpc-0be61d79fb9ca8112"
private_subnet_ids = ["subnet-02ee6e6c8b19a3a7b", "subnet-0013af5c9a372e0f8"]
app_security_group_ids = ["sg-09dcc0ca1f1cb36fe"]  # EKS ClusterSharedNodeSecurityGroup

# Database configuration
postgres_version    = "15"
db_instance_class   = "db.t3.micro"
allocated_storage   = 20
db_name             = "myapp_db_dev"
db_username         = "postgres"

# Backup configuration
backup_retention_period = 3
skip_final_snapshot     = true

# Auto-deploy enabled

