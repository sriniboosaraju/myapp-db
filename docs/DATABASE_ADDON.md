# Database Addon - Akkeris Style

This directory contains the Akkeris-style database addon functionality that allows you to easily provision and attach PostgreSQL databases to your application.

## Quick Start

### Create and Attach Database

```bash
# Create database for dev environment
./scripts/addon-db.sh dev create

# Create database for production
./scripts/addon-db.sh prod create
```

This single command will:
1. ✅ Provision PostgreSQL database using Terraform
2. ✅ Create Kubernetes namespace if needed
3. ✅ Store credentials in Kubernetes secrets
4. ✅ Automatically inject environment variables into your app

### View Database Information

```bash
./scripts/addon-db.sh dev info
```

### Remove Database

```bash
./scripts/addon-db.sh dev remove
```

## How It Works

### 1. Database Provisioning

The addon uses Terraform to provision an AWS RDS PostgreSQL database with:
- Encryption at rest
- Automated backups
- Security groups for network isolation
- AWS Secrets Manager integration

### 2. Credential Management

Database credentials are:
- Stored in AWS Secrets Manager (master copy)
- Synced to Kubernetes Secrets for app access
- Automatically rotated (when configured)

### 3. Application Integration

Your application automatically receives these environment variables:
- `DB_HOST` - Database hostname
- `DB_PORT` - Database port (5432)
- `DB_NAME` - Database name
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password

### 4. Helm Chart Integration

The Helm chart automatically:
- Reads credentials from the Kubernetes secret
- Injects them as environment variables
- Configures the deployment to use the database

## Architecture

```
┌─────────────────┐
│  addon-db.sh    │  ← User runs this script
└────────┬────────┘
         │
         ├─► Terraform (infra/rds-addon/) ──► AWS RDS PostgreSQL
         │                          │
         │                          ├─► DB Subnet Group
         │                          ├─► Security Group
         │                          └─► Secrets Manager
         │
         └─► kubectl ──► Kubernetes Secret (myapp-db-credentials)
                         │
                         └─► Pod Environment Variables
                             ├─► DB_HOST
                             ├─► DB_PORT
                             ├─► DB_NAME
                             ├─► DB_USER
                             └─► DB_PASSWORD
```

## Environment-Specific Configuration

Each environment has its own Terraform variables file:

- **Dev**: `infra/rds-addon/environments/dev.tfvars`
  - Instance: `db.t3.micro`
  - Storage: 20 GB
  - Backups: 3 days
  
- **QA**: `infra/rds-addon/environments/qa.tfvars`
  - Instance: `db.t3.small`
  - Storage: 30 GB
  - Backups: 5 days

- **Staging**: `infra/rds-addon/environments/staging.tfvars`
  - Instance: `db.t3.medium`
  - Storage: 50 GB
  - Backups: 7 days

- **Production**: `infra/rds-addon/environments/prod.tfvars`
  - Instance: `db.r6g.large`
  - Storage: 100 GB
  - Backups: 30 days

## Usage Examples

### Development Workflow

```bash
# 1. Create database
./scripts/addon-db.sh dev create

# 2. Deploy your app (ArgoCD will sync automatically)
# Or manually:
helm upgrade --install myapp-db charts/myapp-db \
  --namespace myapp-db-dev \
  --values charts/myapp-db/values-dev.yaml

# 3. Test the connection
kubectl run psql-test --rm -it \
  --image=postgres:15 \
  --namespace=myapp-db-dev \
  -- psql -h <DB_HOST> -U postgres -d myapp-db_dev
```

### CI/CD Integration

The addon script can be integrated into your CI/CD pipeline:

```yaml
# In your GitHub Actions workflow
- name: Provision Database
  run: ./scripts/addon-db.sh ${{ env.ENVIRONMENT }} create
  
- name: Deploy Application
  run: |
    argocd app sync myapp-db-${{ env.ENVIRONMENT }}
```

## Troubleshooting

### Check database status

```bash
./scripts/addon-db.sh dev info
```

### Verify Kubernetes secret

```bash
kubectl get secret myapp-db-credentials -n myapp-db-dev -o yaml
```

### View secret values

```bash
kubectl get secret myapp-db-credentials -n myapp-db-dev -o jsonpath='{.data.DB_HOST}' | base64 -d
```

### Test database connection from pod

```bash
kubectl exec -it <pod-name> -n myapp-db-dev -- env | grep DB_
```

### Manual connection test

```bash
kubectl run psql-test --rm -it \
  --image=postgres:15 \
  --namespace=myapp-db-dev \
  --env="PGPASSWORD=$(kubectl get secret myapp-db-credentials -n myapp-db-dev -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)" \
  -- psql -h $(kubectl get secret myapp-db-credentials -n myapp-db-dev -o jsonpath='{.data.DB_HOST}' | base64 -d) \
       -U postgres \
       -d myapp-db_dev
```

## Security Best Practices

1. **Never commit database passwords** to git
2. **Use AWS Secrets Manager** for production passwords
3. **Rotate credentials regularly** (configure in Secrets Manager)
4. **Limit database access** using security groups
5. **Enable encryption** at rest and in transit
6. **Use IAM authentication** when possible

## Comparison with Akkeris

| Feature | Akkeris | This Solution |
|---------|---------|---------------|
| Command | `akkeris addons:create postgres` | `./scripts/addon-db.sh dev create` |
| Auto-provision | ✅ | ✅ |
| Auto-attach | ✅ | ✅ |
| Env vars injection | ✅ | ✅ |
| Multi-environment | ✅ | ✅ |
| Infrastructure as Code | Limited | ✅ Full Terraform |
| Secret Management | Built-in | AWS Secrets Manager + K8s |
| Backup Management | Automated | Automated (AWS RDS) |

## Advanced Usage

### Custom database configuration

Edit the environment-specific tfvars file before creating:

```bash
vim infra/rds-addon/environments/dev.tfvars
./scripts/addon-db.sh dev create
```

### Use existing VPC

Update the tfvars file with your VPC details:

```hcl
vpc_id = "vpc-your-vpc-id"
private_subnet_ids = ["subnet-1", "subnet-2"]
app_security_group_ids = ["sg-your-app-sg"]
```

### Multiple databases per environment

Modify the Terraform configuration to support multiple database instances or use database schemas within a single instance.

## Support

For issues or questions:
1. Check the logs: `./scripts/addon-db.sh dev info`
2. Review Terraform state: `cd infra/rds-addon && terraform show`
3. Check Kubernetes events: `kubectl get events -n myapp-db-dev`
