#!/bin/bash
# Script to deploy Backstage to AKS manually
# Usage: ./scripts/deploy-to-aks.sh <ACR_NAME> <IMAGE_TAG>

set -e

ACR_NAME=${1:-"your-acr-name"}
IMAGE_TAG=${2:-"latest"}
NAMESPACE="backstage"

if [ "$ACR_NAME" == "your-acr-name" ]; then
  echo "Error: Please provide your ACR name as the first argument"
  echo "Usage: ./scripts/deploy-to-aks.sh <ACR_NAME> <IMAGE_TAG>"
  exit 1
fi

IMAGE_NAME="${ACR_NAME}.azurecr.io/backstage-app:${IMAGE_TAG}"

echo "Deploying Backstage to AKS..."
echo "ACR Name: ${ACR_NAME}"
echo "Image: ${IMAGE_NAME}"
echo "Namespace: ${NAMESPACE}"

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Update deployment.yaml with actual image name
sed "s|ACR_NAME.azurecr.io/backstage-app:latest|${IMAGE_NAME}|g" k8s/deployment.yaml > /tmp/deployment.yaml

# Apply manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f /tmp/deployment.yaml
kubectl apply -f k8s/service.yaml

# Optionally apply ingress
if [ -f "k8s/ingress.yaml" ]; then
  kubectl apply -f k8s/ingress.yaml
fi

# Wait for deployment
echo "Waiting for deployment to complete..."
kubectl rollout status deployment/backstage -n ${NAMESPACE} --timeout=5m

echo "Deployment complete!"
echo "Check status with: kubectl get pods -n ${NAMESPACE}"
