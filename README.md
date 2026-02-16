# My Monorepo - GitOps with ArgoCD

This repository demonstrates a GitOps workflow using ArgoCD, Helm, and GitHub Actions.

## Project Structure

```
my-monorepo/
├── app/                          # Node.js application
│   ├── package.json
│   ├── index.js
│   └── Dockerfile
├── charts/                       # Helm charts
│   └── myapp-db/
│       ├── Chart.yaml
│       ├── values.yaml          # Base values
│       ├── values-dev.yaml      # Dev environment (updated by CI)
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           └── _helpers.tpl
├── deploy/                       # ArgoCD manifests
│   └── apps/
│       └── myapp-db-dev-app.yaml
└── .github/
    └── workflows/
        └── ci-build-and-update-values.yml
```

## Setup Instructions

### 1. Replace Placeholders

Before pushing to GitHub, replace the following placeholders:

- `<GITHUB_OWNER>` in:
  - `charts/myapp-db/values.yaml`
  - `charts/myapp-db/values-dev.yaml`
  - `deploy/apps/myapp-db-dev-app.yaml`
- `<REPO>` in:
  - `deploy/apps/myapp-db-dev-app.yaml`

### 2. GitHub Actions Permissions

The workflow requires:
- `contents: write` - to commit updated values back to the repo
- `packages: write` - to push images to GitHub Container Registry (GHCR)

These are already configured in the workflow file.

### 3. ArgoCD Setup

1. **Add repository to ArgoCD:**
   ```bash
   # Via UI: Settings → Repositories → Connect Repo
   # Or via CLI:
   argocd repo add https://github.com/<GITHUB_OWNER>/<REPO>.git
   ```

2. **Create the Application:**
   ```bash
   kubectl apply -f deploy/apps/myapp-db-dev-app.yaml -n argocd
   ```

3. **Verify the application:**
   ```bash
   argocd app get myapp-db-dev
   argocd app sync myapp-db-dev
   ```

### 4. Trigger the CI/CD Pipeline

Push any change to the `main` branch to trigger the workflow:

```bash
git add .
git commit -m "Initial commit"
git push origin main
```

The workflow will:
1. Build the Docker image
2. Push to GHCR with tags: `<short-sha>` and `latest`
3. Update `charts/myapp-db/values-dev.yaml` with the new tag
4. Commit and push the change back to the repo

ArgoCD will detect the change and automatically sync the deployment.

## How It Works

1. **Developer pushes code** → GitHub Actions workflow triggers
2. **Workflow builds image** → Pushes to GHCR with Git SHA tag
3. **Workflow updates values-dev.yaml** → Commits back to repo
4. **ArgoCD detects change** → Pulls updated chart and values
5. **ArgoCD syncs** → Deploys new image to Kubernetes cluster

## Local Development

Run the app locally:

```bash
cd app
npm install
npm start
```

Access at http://localhost:3000

## Notes

- Images are tagged with short Git SHA for immutability and traceability
- `[ci skip]` in commit message prevents recursive CI triggers
- For production, consider PR-based promotions instead of auto-commit
- If GHCR images are private, configure `imagePullSecrets` in Kubernetes

## Advanced Options

### Separate GitOps Repository

For better separation, you can maintain charts in a separate repo and have CI update that repo instead.

### PR-Based Promotion

For staging/production, create a PR to update values instead of direct commit, requiring manual approval.

### Multi-Environment Support

Add `values-staging.yaml`, `values-prod.yaml` and corresponding ArgoCD Applications.
