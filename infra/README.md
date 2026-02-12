# Infrastructure - PostgreSQL Database

This directory contains Terraform configuration to provision a PostgreSQL database on AWS RDS.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Existing VPC with private subnets

## Resources Created

- **RDS PostgreSQL Instance**: Managed PostgreSQL database
- **DB Subnet Group**: Subnet group for database placement
- **Security Group**: Network security for database access
- **Secrets Manager Secret**: Secure storage for database credentials

## Configuration

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your specific values:
   - VPC ID
   - Private subnet IDs
   - Application security group IDs
   - Database password
   - Environment name

## Usage

### Initialize Terraform
```bash
terraform init
```

### Plan Changes
```bash
terraform plan
```

### Apply Changes
```bash
terraform apply
```

### Destroy Resources
```bash
terraform destroy
```

## Environment-Specific Configuration

You can create environment-specific variable files:

```bash
terraform apply -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/prod.tfvars"
```

## Outputs

After applying, Terraform will output:
- Database endpoint and address
- Database port and name
- Security group ID
- Secrets Manager ARN for credentials

## Security Notes

- Database password is marked as sensitive
- Database is placed in private subnets
- Access is restricted via security groups
- Credentials are stored in AWS Secrets Manager
- Storage encryption is enabled
- Backup retention is configured

## Connecting to the Database

Use the outputs to connect your application:

```bash
# Get database endpoint
terraform output db_instance_address

# Get credentials from Secrets Manager
aws secretsmanager get-secret-value --secret-id $(terraform output -raw db_credentials_secret_arn)
```

## Environment Variables for Application

Set these environment variables in your application deployment:

```bash
DB_HOST=$(terraform output -raw db_instance_address)
DB_PORT=$(terraform output -raw db_instance_port)
DB_NAME=$(terraform output -raw db_instance_name)
DB_USER=$(terraform output -raw db_instance_username)
DB_PASSWORD=<from-secrets-manager-or-secure-store>
```
