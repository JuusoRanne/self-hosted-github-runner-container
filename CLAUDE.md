# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains infrastructure and configuration for a self-hosted GitHub Actions runner deployed on Azure Container Apps. The setup uses GitHub App authentication for secure runner registration and management.

## Core Architecture

### Infrastructure Components
- **Terraform Configuration**: Azure resources defined in `main.tf`
  - Azure Container Apps environment with consumption-based scaling
  - User-assigned managed identity for authentication
  - Virtual network with delegated subnet
  - Storage account with queue for potential scaling triggers
- **Docker Container**: Ubuntu 24.04-based image with GitHub Actions runner
- **Authentication**: GitHub App-based authentication via JWT tokens

### Key Files
- `dockerfile`: Defines the container image with GitHub Actions runner and dependencies
- `start.sh`: Container entrypoint script that handles GitHub App authentication and runner registration
- `main.tf`: Terraform infrastructure definition
- `variables.tf`: Terraform variable definitions
- `provider.tf`: Terraform provider configuration (Azure with OIDC)

## Development Commands

### Terraform Operations
```bash
# Initialize Terraform with production backend
terraform init -upgrade -backend-config=backend-prod.tfvars

# Validate configuration
terraform validate

# Plan deployment
terraform plan -var-file=env/prod.tfvars

# Apply changes
terraform apply -var-file=env/prod.tfvars -auto-approve
```

### Docker Operations
```bash
# Build container image
docker build . -t creuwbfcommonsp.azurecr.io/infrastructure/github-runner:latest

# Push to Azure Container Registry
docker push creuwbfcommonsp.azurecr.io/infrastructure/github-runner:latest
```

## Configuration Requirements

### Environment Variables for Container
- `APP_ID`: GitHub App ID
- `APP_PRIVATE_KEY`: GitHub App private key (RSA format)
- `GH_OWNER`: GitHub organization name
- `RUNNER_NAME`: Name for the runner instance

### Terraform Variables
- `app_name`: Application name for resource naming
- `environment`: Deployment environment (prod)
- `acr_login_server`: Azure Container Registry server
- `acr_tag`: Container image tag
- `container_cpu`: CPU allocation (default: 0.5)
- `container_memory`: Memory allocation (default: 1.0Gi)

## GitHub Actions Workflows

### Image Build and Push (`BuildAndPushToAzureContainerRegistry.yml`)
- Triggered manually via workflow_dispatch
- Builds and pushes container image to ACR
- Updates `CONTAINER_IMAGE_NAME` repository variable with new SHA
- Uses GitHub App authentication for API calls

### Infrastructure Deployment (`deploy-infra.yml`)
- Two-stage deployment (plan and apply)
- Uses OIDC authentication with Azure
- Deploys infrastructure changes using Terraform

## Authentication Flow

The GitHub runner uses a GitHub App for authentication:
1. Container generates JWT using App ID and private key
2. Fetches installation token for the organization
3. Uses installation token to get runner registration token
4. Configures runner with registration token
5. Cleanup handler removes runner on container termination

## Resource Naming Convention
Azure resources follow the pattern: `{type}-{location}-{app_name}-{environment}`
- Example: `ca-euw-ghrunner-prod` (Container App)
- Example: `vn-euw-ghrunner-prod` (Virtual Network)