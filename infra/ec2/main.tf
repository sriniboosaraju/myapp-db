# -------------------------------------------------------------------
# EC2 Instance for myapp-db application
# -------------------------------------------------------------------

# Lookup the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role for EC2 instance (SSM access + CloudWatch logs)
resource "aws_iam_role" "ec2" {
  name = "${var.app_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-${var.environment}-ec2-role"
    Environment = var.environment
    AppName     = var.app_name
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.app_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name        = "${var.app_name}-${var.environment}-ec2-profile"
    Environment = var.environment
    AppName     = var.app_name
    ManagedBy   = "Terraform"
  }
}

# Security group for the EC2 instance
resource "aws_security_group" "ec2" {
  name        = "${var.app_name}-${var.environment}-ec2-sg"
  description = "Security group for ${var.app_name} EC2 instance"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-ec2-sg"
    Environment = var.environment
    AppName     = var.app_name
    ManagedBy   = "Terraform"
  }
}

# Optional: allow inbound SSH from a trusted CIDR
resource "aws_security_group_rule" "ec2_ssh" {
  count             = var.ec2_ssh_cidr != "" ? 1 : 0
  type              = "ingress"
  description       = "SSH access from trusted CIDR"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.ec2_ssh_cidr]
  security_group_id = aws_security_group.ec2.id
}

# EC2 instance
resource "aws_instance" "app" {
  ami                    = var.ec2_ami != "" ? var.ec2_ami : data.aws_ami.amazon_linux_2023.id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.ec2_subnet_id != "" ? var.ec2_subnet_id : var.private_subnet_ids[0]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = concat([aws_security_group.ec2.id], var.ec2_extra_security_group_ids)

  key_name                    = var.ec2_key_name != "" ? var.ec2_key_name : null
  associate_public_ip_address = var.ec2_associate_public_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.ec2_root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name        = "${var.app_name}-${var.environment}-ec2-root"
      Environment = var.environment
      AppName     = var.app_name
      ManagedBy   = "Terraform"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    app_name    = var.app_name
    environment = var.environment
    aws_region  = var.aws_region
  }))

  tags = {
    Name        = "Demo-ec2"
    Environment = var.environment
    AppName     = var.app_name
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

# Optional: Elastic IP for the instance
resource "aws_eip" "ec2" {
  count    = var.ec2_associate_public_ip && var.ec2_create_eip ? 1 : 0
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name        = "${var.app_name}-${var.environment}-ec2-eip"
    Environment = var.environment
    AppName     = var.app_name
    ManagedBy   = "Terraform"
  }
}
