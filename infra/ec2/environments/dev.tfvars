environment = "dev"
aws_region  = "us-east-1"

# Network configuration - EKS Srini Cluster VPC
vpc_id             = "vpc-0be61d79fb9ca8112"
private_subnet_ids = ["subnet-02ee6e6c8b19a3a7b", "subnet-0013af5c9a372e0f8"]

# EC2 configuration
ec2_instance_type        = "t3.medium"
ec2_ami                  = ""       # leave empty to use latest Amazon Linux 2023
ec2_subnet_id            = ""       # leave empty to use first private subnet
ec2_key_name             = ""       # leave empty to disable key-based SSH
ec2_ssh_cidr             = ""       # leave empty to disable SSH ingress rule
ec2_root_volume_size  
ec2_associate_public_ip  = false
ec2_create_eip           = false
ec2_extra_security_group_ids = []
