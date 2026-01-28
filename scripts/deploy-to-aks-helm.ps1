# PowerShell script to deploy Backstage to AKS using Helm
# Usage: .\deploy-to-aks-helm.ps1 -RegistryUrl "myacr.azurecr.io" -ImageTag "latest"

param(
    [Parameter(Mandatory=$true)]
    [string]$RegistryUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "latest",
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "backstage",
    
    [Parameter(Mandatory=$false)]
    [string]$HelmReleaseName = "backstage",
    
    [Parameter(Mandatory=$false)]
    [string]$HelmChartPath = "./helm/backstage",
    
    [Parameter(Mandatory=$false)]
    [string]$ValuesFile = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$Wait
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

# Display configuration
Write-Success "Backstage Helm Deployment Configuration"
Write-Host "========================================"
Write-Host "Helm Release Name: $HelmReleaseName"
Write-Host "Helm Chart Path:   $HelmChartPath"
Write-Host "Namespace:         $Namespace"
Write-Host "Registry URL:      $RegistryUrl"
Write-Host "Image Tag:         $ImageTag"
Write-Host "Dry Run:           $DryRun"
Write-Host "========================================"

# Check if Helm is installed
try {
    $helmVersion = helm version --short
    Write-Success "Helm found: $helmVersion"
}
catch {
    Write-Error "Error: Helm is not installed or not in PATH"
    exit 1
}

# Check if kubectl is installed
try {
    $kubectlVersion = kubectl version --client --short
    Write-Success "kubectl found: $kubectlVersion"
}
catch {
    Write-Error "Error: kubectl is not installed or not in PATH"
    exit 1
}

# Verify Helm chart exists
$chartFile = Join-Path $HelmChartPath "Chart.yaml"
if (-not (Test-Path $chartFile)) {
    Write-Error "Error: Helm chart not found at $chartFile"
    exit 1
}

# Check cluster connectivity    
Write-Warning "`nChecking AKS cluster connectivity..."
try {
    $clusterInfo = kubectl cluster-info
    $currentContext = kubectl config current-context
    Write-Success "Connected to cluster: $currentContext"
}
catch {
    Write-Error "Error: Cannot connect to Kubernetes cluster"
    Write-Error "Please ensure you are logged in and have access to the cluster"
    exit 1
}

# Prepare Helm values
Write-Warning "`nPreparing Helm deployment..."
$imageRepository = "$RegistryUrl/backstage-app"

# Build Helm command
$helmArgs = @(
    "upgrade", "--install", $HelmReleaseName, $HelmChartPath,
    "--namespace", $Namespace,
    "--create-namespace",
    "--set", "backstage.image.repository=$imageRepository",
    "--set", "backstage.image.tag=$ImageTag",
    "--timeout", "10m"
)

if ($ValuesFile -and (Test-Path $ValuesFile)) {
    $helmArgs += @("-f", $ValuesFile)
}

if ($DryRun) {
    $helmArgs += @("--dry-run", "--debug")
}

# Execute Helm deployment
Write-Warning "`nDeploying Backstage with Helm..."
Write-Host "`nHelm command: helm $(($helmArgs -join ' '))"
Write-Host ""

try {
    & helm $helmArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Helm deployment failed with exit code $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "Error executing Helm: $_"
    exit 1
}

if ($DryRun) {
    Write-Success "`nDry run completed. No changes were applied."
    exit 0
}

# Wait for deployment if requested
if ($Wait) {
    Write-Warning "`nWaiting for deployment to be ready (max 5 minutes)..."
    try {
        $output = kubectl rollout status deployment/backstage -n $Namespace --timeout=5m
        Write-Success "`nDeployment successful!"
    }
    catch {
        Write-Error "`nDeployment timed out or failed"
        Write-Host "Check status with: kubectl get pods -n $Namespace"
        exit 1
    }
}

# Display deployment information
Write-Success "`nDeployment Information:"
Write-Host "========================================"

# Get Service info
Write-Host "`nServices:"
kubectl get svc -n $Namespace

# Get Pods info
Write-Host "`nPods:"
kubectl get pods -n $Namespace

# Get Ingress info if exists
try {
    $ingresses = kubectl get ingress -n $Namespace 2>$null
    if ($ingresses) {
        Write-Host "`nIngresses:"
        kubectl get ingress -n $Namespace
    }
}
catch {
    # Ingress not found, that's OK
}

# Display helpful commands
Write-Success "`nNext steps:"
Write-Host "1. Verify all pods are running:"
Write-Host "   kubectl get pods -n $Namespace"
Write-Host ""
Write-Host "2. Check logs:"
Write-Host "   kubectl logs -n $Namespace deployment/backstage"
Write-Host ""
Write-Host "3. Port forward to test locally:"
Write-Host "   kubectl port-forward -n $Namespace svc/backstage 7007:80"
Write-Host ""
Write-Host "4. View Helm release:"
Write-Host "   helm list -n $Namespace"
Write-Host ""
Write-Host "5. Describe resources:"
Write-Host "   kubectl describe pod -n $Namespace"

Write-Success "`nDeployment process completed!"
