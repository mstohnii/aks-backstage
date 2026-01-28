# Backstage Helm Deployment

## Getting Started

You'll need these installed and configured:
- AKS cluster
- ACR with the Backstage image
- kubectl
- Helm

## Deploy

Update `helm/backstage/values.yaml` with your settings:

```yaml
backstage:
  image:
    repository: <YOUR-ACR>.azurecr.io/backstage-app
    tag: latest

  config:
    app:
      baseUrl: "http://<YOUR-DOMAIN>"
    backend:
      baseUrl: "http://<YOUR-DOMAIN>"

postgresql:
  auth:
    password: "your-password"
    postgresPassword: "your-postgres-password"

secrets:
  backendSecret: "your-secret-key"
```

Then deploy:

**PowerShell:**
```powershell
.\scripts\deploy-to-aks-helm.ps1 `
  -RegistryUrl "<YOUR-ACR>.azurecr.io" `
  -ImageTag "latest" `
  -Wait
```

**Bash:**
```bash
./scripts/deploy-to-aks-helm.sh \
  -r <YOUR-ACR>.azurecr.io \
  -t latest
```

## Common Configuration

Update these in `values.yaml`:

- `backstage.image.repository` - Your ACR image path
- `backstage.image.tag` - Image version
- `backstage.config.app.baseUrl` - App URL
- `backstage.config.backend.baseUrl` - Backend URL
- `postgresql.auth.password` - Database password
- `backstage.replicaCount` - Number of replicas

For production, use `values-production.yaml`:

```bash
helm upgrade --install backstage ./helm/backstage \
  -f helm/backstage/values-production.yaml
```