# Application Build and Deploy Pipeline

This workflow automatically builds your application and provisions the database when you push code.

## What Happens Automatically

When you push code to `develop` or `main` branches:

1. **Build** 🏗️
   - Builds Docker image
   - Pushes to GitHub Container Registry
   - Tags with commit SHA

2. **Database Provisioning** 🗄️
   - Checks if database exists for the environment
   - Creates PostgreSQL database (only if it doesn't exist)
   - Retrieves credentials from AWS Secrets Manager
   - Creates Kubernetes secret with credentials
   - Attaches database to your app

3. **Deploy** 🚀
   - Deploys app to Kubernetes with Helm
   - Injects database environment variables automatically
   - Verifies deployment is healthy

## Environments

- **`develop` branch** → Deploys to `dev` environment
- **`main` branch** → Deploys to `staging`, then `prod` (with approval)

## Required GitHub Secrets

Set these in your repository settings:

### AWS & Infrastructure
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `TF_STATE_BUCKET` - S3 bucket for Terraform state
- `EKS_CLUSTER_NAME_DEV` - Dev Kubernetes cluster name
- `EKS_CLUSTER_NAME_STAGING` - Staging Kubernetes cluster name
- `EKS_CLUSTER_NAME_PROD` - Production Kubernetes cluster name

### Database Passwords
- `DB_PASSWORD_DEV` - Dev database password
- `DB_PASSWORD_STAGING` - Staging database password
- `DB_PASSWORD_PROD` - Production database password

## Usage

### Automatic Deployment

Just push your code:

```bash
# Deploy to dev
git push origin develop

# Deploy to staging and prod
git push origin main
```

### Manual Deployment

Trigger manually from GitHub Actions UI:
1. Go to Actions tab
2. Select "Build and Deploy App"
3. Click "Run workflow"
4. Choose environment

## What You Get

After the pipeline runs:

✅ Docker image built and pushed  
✅ PostgreSQL database provisioned (if needed)  
✅ Database credentials stored securely in Kubernetes  
✅ App deployed with database automatically connected  
✅ Environment variables injected:
   - `DB_HOST`
   - `DB_PORT`
   - `DB_NAME`
   - `DB_USER`
   - `DB_PASSWORD`

## Database Creation

The pipeline intelligently handles database creation:

- **First run**: Creates database, attaches to app
- **Subsequent runs**: Skips database creation, just attaches credentials
- **Never destroys data**: Database persists across deployments

## Pipeline Flow

```
┌─────────────┐
│ Push Code   │
└──────┬──────┘
       │
       ├──► Build Docker Image
       │
       ├──► Check Database
       │    ├─► Exists? → Skip creation
       │    └─► Missing? → Create database
       │
       ├──► Attach Database to App
       │    ├─► Create K8s secret
       │    └─► Label for app
       │
       └──► Deploy Application
            ├─► Helm upgrade
            └─► Verify rollout
```

## Viewing Pipeline Results

After each run, check:

1. **Summary** - See deployment details in GitHub Actions summary
2. **Logs** - View detailed logs for each step
3. **Database Info** - Connection details printed in logs

## Troubleshooting

### Database not created
- Check AWS credentials are valid
- Verify Terraform state bucket exists
- Check environment-specific tfvars file

### App can't connect to database
- Verify Kubernetes secret exists: `kubectl get secret myapp-db-credentials -n myapp-dev`
- Check secret has correct keys: `kubectl describe secret myapp-db-credentials -n myapp-dev`
- View pod environment: `kubectl exec <pod-name> -n myapp-dev -- env | grep DB_`

### Deployment fails
- Check pod logs: `kubectl logs -n myapp-dev -l app=myapp`
- Verify image was built: Check GitHub Container Registry
- Check Helm release: `helm list -n myapp-dev`

## Comparing with Akkeris

| Akkeris | This Pipeline |
|---------|---------------|
| `git push` | ✅ `git push` |
| Auto-builds | ✅ Auto-builds |
| Auto-provisions DB | ✅ Auto-provisions DB |
| Auto-attaches DB | ✅ Auto-attaches DB |
| Auto-deploys | ✅ Auto-deploys |

It's the same experience! Just push your code and everything is handled automatically.
