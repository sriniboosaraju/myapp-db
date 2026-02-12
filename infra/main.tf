# Generate random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Generate random suffix for database name
resource "random_string" "db_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_db_instance" "postgres" {
  identifier           = "${var.app_name}-${var.environment}-db"
  engine              = "postgres"
  engine_version      = var.postgres_version
  instance_class      = var.db_instance_class
  allocated_storage   = var.allocated_storage
  storage_type        = "gp3"
  storage_encrypted   = true

  db_name  = "testing_${random_string.db_suffix.result}"
  username = var.db_username
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.postgres.id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name

  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = "${var.app_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name        = "${var.app_name}-${var.environment}-postgres"
    Environment = var.environment
    AppName     = var.app_name
    ManagedBy   = "Terraform"
    Addon       = "postgres"
  }
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.app_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.app_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_security_group" "postgres" {
  name        = "${var.app_name}-${var.environment}-postgres-sg"
  description = "Security group for PostgreSQL database"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from application"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.app_security_group_ids
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-${var.environment}-postgres-sg"
    Environment = var.environment
  }
}

# Secret for database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.app_name}-${var.environment}-db-credentials"
  description = "Database credentials for ${var.app_name} ${var.environment}"

  tags = {
    Name        = "${var.app_name}-${var.environment}-db-credentials"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.postgres.username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
  })
}
