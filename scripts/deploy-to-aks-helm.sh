#!/bin/bash
# Backstage Helm Deployment Script
# This script deploys Backstage with PostgreSQL to AKS using Helm

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
HELM_RELEASE_NAME="backstage"
HELM_CHART_PATH="./helm/backstage"
KUBE_NAMESPACE="backstage"
ACR_REGISTRY=""
IMAGE_TAG="latest"
VALUES_FILE="helm/backstage/values.yaml"
DRY_RUN=false

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 -r <acr-registry> [OPTIONS]

Required:
  -r, --registry <acr-registry>    ACR registry URL (e.g., myacr.azurecr.io)

Optional:
  -t, --tag <tag>                 Docker image tag (default: latest)
  -n, --namespace <namespace>     Kubernetes namespace (default: backstage)
  -c, --chart-path <path>         Path to Helm chart (default: ./helm/backstage)
  -v, --values <file>             Custom values file
  --dry-run                       Show what would be deployed without applying
  -h, --help                      Show this help message

Examples:
  $0 -r myacr.azurecr.io -t v1.47.0
  $0 -r myacr.azurecr.io -t latest --dry-run

EOF
    exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            ACR_REGISTRY="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -n|--namespace)
            KUBE_NAMESPACE="$2"
            shift 2
            ;;
        -c|--chart-path)
            HELM_CHART_PATH="$2"
            shift 2
            ;;
        -v|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$ACR_REGISTRY" ]; then
    echo -e "${RED}Error: ACR registry is required${NC}"
    usage
fi

# Display configuration
echo -e "${GREEN}Backstage Helm Deployment Configuration${NC}"
echo "========================================"
echo "Release Name:     $HELM_RELEASE_NAME"
echo "Chart Path:       $HELM_CHART_PATH"
echo "Namespace:        $KUBE_NAMESPACE"
echo "ACR Registry:     $ACR_REGISTRY"
echo "Image Tag:        $IMAGE_TAG"
echo "Dry Run:          $DRY_RUN"
echo "========================================"

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: Helm is not installed${NC}"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Verify Helm chart exists
if [ ! -f "$HELM_CHART_PATH/Chart.yaml" ]; then
    echo -e "${RED}Error: Helm chart not found at $HELM_CHART_PATH/Chart.yaml${NC}"
    exit 1
fi

# Check cluster connectivity
echo -e "\n${YELLOW}Checking AKS cluster connectivity...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure you are logged in and have access to the cluster"
    exit 1
fi

CLUSTER_NAME=$(kubectl config current-context)
echo -e "${GREEN}Connected to cluster: $CLUSTER_NAME${NC}"

# Create namespace if it doesn't exist
echo -e "\n${YELLOW}Creating namespace if it doesn't exist...${NC}"
kubectl create namespace $KUBE_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Update image repository in values
echo -e "\n${YELLOW}Updating Helm values...${NC}"
IMAGE_REPO="${ACR_REGISTRY}/backstage-app"

# Build Helm command
HELM_CMD="helm upgrade --install $HELM_RELEASE_NAME $HELM_CHART_PATH \
  --namespace $KUBE_NAMESPACE \
  --set backstage.image.repository=$IMAGE_REPO \
  --set backstage.image.tag=$IMAGE_TAG \
  --timeout 10m"

if [ -f "$VALUES_FILE" ]; then
    HELM_CMD="$HELM_CMD -f $VALUES_FILE"
fi

if [ "$DRY_RUN" = true ]; then
    HELM_CMD="$HELM_CMD --dry-run --debug"
    echo -e "\n${YELLOW}Dry Run - Helm command:${NC}"
    echo "$HELM_CMD"
    eval $HELM_CMD
    exit 0
fi

# Deploy using Helm
echo -e "\n${YELLOW}Deploying Backstage with Helm...${NC}"
eval $HELM_CMD

# Wait for deployment
echo -e "\n${YELLOW}Waiting for deployment to be ready (max 5 minutes)...${NC}"
if kubectl rollout status deployment/backstage -n $KUBE_NAMESPACE --timeout=5m; then
    echo -e "\n${GREEN}Deployment successful!${NC}"
else
    echo -e "\n${RED}Deployment timed out or failed${NC}"
    echo "Check status with: kubectl get pods -n $KUBE_NAMESPACE"
    exit 1
fi

# Display deployment information
echo -e "\n${GREEN}Deployment Information:${NC}"
echo "========================================"

# Get Service info
echo -e "\nServices:"
kubectl get svc -n $KUBE_NAMESPACE

# Get Pods info
echo -e "\nPods:"
kubectl get pods -n $KUBE_NAMESPACE

# Get Ingress info if exists
if kubectl get ingress -n $KUBE_NAMESPACE &> /dev/null; then
    echo -e "\nIngresses:"
    kubectl get ingress -n $KUBE_NAMESPACE
fi

echo -e "\n${GREEN}Next steps:${NC}"
echo "1. Verify all pods are running: kubectl get pods -n $KUBE_NAMESPACE"
echo "2. Check logs: kubectl logs -n $KUBE_NAMESPACE deployment/backstage"
echo "3. Port forward to test locally: kubectl port-forward -n $KUBE_NAMESPACE svc/backstage 7007:80"
echo "4. View Helm release: helm list -n $KUBE_NAMESPACE"

echo -e "\n${GREEN}Deployment completed!${NC}"
