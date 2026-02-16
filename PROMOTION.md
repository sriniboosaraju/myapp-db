# Promotion Workflow

## Environments

| Environment | Auto-Deploy | Manual Promotion |
|------------|-------------|------------------|
| Dev | ✅ (on push to main) | - |
| QA | ❌ | Dev → QA |
| Staging | ❌ | QA → Staging |
| Production | ❌ | Staging → Prod (requires "APPROVE") |

## Quick Start

### 1. Deploy to Dev (Automatic)
```bash
git add .
git commit -m "Your changes"
git push origin main
# ✅ Auto-deploys to Dev with Git SHA tag (e.g., abc1234)
```

### 2. Promote to QA
1. Go to: https://github.com/sriniboosaraju/myapp-db/actions
2. Run **"Promote to QA"** workflow
3. Enter Git SHA from Dev (e.g., `abc1234`)

### 3. Promote to Staging
1. Run **"Promote to Staging"** workflow
2. Enter the same Git SHA tested in QA

### 4. Promote to Production
1. Run **"Promote to Production"** workflow
2. Enter Git SHA
3. Type **"APPROVE"** to confirm

## Find Current Tag

```bash
# From Dev deployment
cat charts/myapp-db/values-dev.yaml | grep tag

# From Git history
git log --oneline -5
```

## Setup (One-time)

```bash
# Create namespaces
kubectl create namespace myapp-db-qa
kubectl create namespace myapp-db-staging
kubectl create namespace myapp-db-prod

# Deploy ArgoCD applications
kubectl apply -f deploy/apps/myapp-db-qa-app.yaml -n argocd
kubectl apply -f deploy/apps/myapp-db-staging-app.yaml -n argocd
kubectl apply -f deploy/apps/myapp-db-prod-app.yaml -n argocd
```

## Rollback

Run promotion workflow with a previous Git SHA tag.
