# PowerShell script to deploy Backstage to AKS manually
# Usage: .\scripts\deploy-to-aks.ps1 -ACRName "your-acr-name" -ImageTag "latest"

param(
    [Parameter(Mandatory=$true)]
    [string]$ACRName,
    
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "latest",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "backstage"
)

$ErrorActionPreference = "Stop"

$ImageName = "${ACRName}.azurecr.io/backstage-app:${ImageTag}"

Write-Host "Deploying Backstage to AKS..." -ForegroundColor Green
Write-Host "ACR Name: $ACRName"
Write-Host "Image: $ImageName"
Write-Host "Namespace: $Namespace"

# Create namespace
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

# Update deployment.yaml with actual image name
$deploymentContent = Get-Content -Path "k8s\deployment.yaml" -Raw
$deploymentContent = $deploymentContent -replace "ACR_NAME\.azurecr\.io/backstage-app:latest", $ImageName
$deploymentContent | Out-File -FilePath "$env:TEMP\deployment.yaml" -Encoding utf8

# Apply manifests
Write-Host "Applying Kubernetes manifests..." -ForegroundColor Yellow
kubectl apply -f k8s\namespace.yaml
kubectl apply -f k8s\configmap.yaml
kubectl apply -f k8s\secrets.yaml
kubectl apply -f "$env:TEMP\deployment.yaml"
kubectl apply -f k8s\service.yaml

# Optionally apply ingress
if (Test-Path "k8s\ingress.yaml") {
    kubectl apply -f k8s\ingress.yaml
}

# Wait for deployment
Write-Host "Waiting for deployment to complete..." -ForegroundColor Yellow
kubectl rollout status deployment/backstage -n $Namespace --timeout=5m

Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "Check status with: kubectl get pods -n $Namespace" -ForegroundColor Cyan
