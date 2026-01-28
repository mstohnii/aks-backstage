# Backstage App

A Backstage deployment on Azure Kubernetes Service (AKS) with Helm.

## Quick Start

```bash
yarn install
yarn start
```

## Deploy to AKS

See [QUICK_START.md](QUICK_START.md) for Helm deployment instructions.

## Project Structure

- `packages/app` - Frontend React application
- `packages/backend` - Backend Node.js server
- `helm/backstage` - Kubernetes Helm charts
- `scripts` - Deployment scripts for AKS
- `BACKSTAGE_LAB/` - [Backstage lab templates and configurations](./BACKSTAGE_LAB/README.md)