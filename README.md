# Self-Hosted GitHub Actions Runner on Azure Container Apps

This repository contains infrastructure and configuration for deploying a self-hosted GitHub Actions runner on Azure Container Apps. The setup uses GitHub App authentication for secure runner registration and management with automatic scaling capabilities.

## Architecture Overview

The solution consists of:

- **Azure Container Apps Environment**: Consumption-based container hosting with automatic scaling
- **Docker Container**: Ubuntu 24.04-based image with GitHub Actions runner pre-installed
- **GitHub App Authentication**: Secure runner registration using JWT tokens
- **Azure Virtual Network**: Isolated networking with delegated subnet for Container Apps
- **Azure Storage Account**: Queue storage for potential custom scaling triggers
- **Automated CI/CD**: Weekly builds and infrastructure updates via GitHub Actions

## Prerequisites

1. **Azure Subscription** with appropriate permissions
2. **GitHub Organization** or Repository admin access
3. **GitHub App** configured with runner permissions
4. **Azure Container Registry** for storing container images
5. **Terraform** >= 1.0 for infrastructure deployment

## Required GitHub App Permissions

Your GitHub App needs the following permissions:

### Organization Permissions
- **Actions**: Write (to register/remove runners)
- **Administration**: Read (to access organization details)
- **Members**: Read (for organization access)

### Repository Permissions (if using repo-level runners)
- **Actions**: Write
- **Administration**: Read

## Setup Instructions

### 1. Clone Repository

```bash
git clone <repository-url>
cd bf-self-hosted-github-runner
```

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

#### Required Secrets
| Secret Name | Description | Example |
|-------------|-------------|---------|
| `APP_PRIVATE_KEY` | GitHub App private key (RSA format) | `-----BEGIN RSA PRIVATE KEY-----\n...` |
| `AZURE_CLIENT_ID_PROD` | Azure Service Principal Client ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_SUBSCRIPTION_ID_PROD` | Azure Subscription ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | Azure Tenant ID | `12345678-1234-1234-1234-123456789012` |
| `REGISTRY_USERNAME` | Azure Container Registry username | `service-principal-id` |
| `REGISTRY_PASSWORD` | Azure Container Registry password | `service-principal-secret` |

### 3. Configure GitHub Variables

Add the following variables to your GitHub repository:

#### Required Variables
| Variable Name | Description | Example |
|---------------|-------------|---------|
| `APP_ID` | GitHub App ID | `123456` |
| `CONTAINER_IMAGE_NAME` | Container image tag (auto-updated by workflow) | `abc123def456` |
| `REGISTRY_LOGIN_SERVER` | Azure Container Registry URL | `creuwbfcommonsp.azurecr.io` |
| `RUNNER_NAME` | Name for the runner instance | `azure-runner-prod-001` |
| `GH_OWNER` | GitHub organization or username | `businessfinland` |

### 4. Update Terraform Variables

Edit `env/prod.tfvars` with your specific values:

```hcl
app_name = "self-hosted-gh-runner"
environment = "prod"
location_short = "euw"  # West Europe

# Update tags with your organization details
tags = {
  "application_purpose" = "Self-hosted GitHub Runner"
  "business_owner" = "juuso.ranne@businessfinland.fi"
  "cost_centre" = 9606
  "creator" = "Juuso Ranne"
  "environment" = "Development"
  "owner" = "juuso.ranne@businessfinland.fi"
  "partner" = "N/A"
  "project_name" = ""
}

# Network configuration (adjust as needed)
vnet_address_space = ["10.0.0.0/16"]
subnet_address_prefix = ["10.0.0.0/24"]
```

### 5. Configure Terraform Backend

Update `backend-prod.tfvars` with your Terraform state storage details:

```hcl
resource_group_name  = "your-terraform-state-rg"
storage_account_name = "yourterraformstate"
container_name       = "tfstate"
key                  = "github-runner/terraform.tfstate"
```

## Deployment

### Automatic Deployment (Recommended)

The repository includes GitHub Actions workflows for automated deployment:

1. **Build and Push Container**: "Image Build and Push" workflow
   - **Manual trigger**: Via workflow_dispatch 
   - **Scheduled**: Weekly on Monday at 2:00 AM UTC
   - Builds latest container image with current GitHub Actions runner version
   - Pushes to Azure Container Registry with commit SHA as tag
   - Updates repository variables with new image tag
   - Automatically triggers infrastructure deployment

2. **Deploy Infrastructure**: Automatically triggered after image build
   - Runs Terraform plan and apply
   - Deploys/updates Azure resources

### Manual Deployment

#### Step 1: Build and Push Container Image

```bash
# Get latest GitHub Actions runner version
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')

# Build container image
docker build . \
  --platform linux/amd64 \
  --build-arg RUNNER_VERSION=$RUNNER_VERSION \
  -t creuwbfcommonsp.azurecr.io/infrastructure/github-runner:latest

# Push to registry
docker push creuwbfcommonsp.azurecr.io/infrastructure/github-runner:latest
```

#### Step 2: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init -upgrade -backend-config=backend-prod.tfvars

# Plan deployment
terraform plan -var-file=env/prod.tfvars

# Apply changes
terraform apply -var-file=env/prod.tfvars -auto-approve
```

## Usage

### Runner Registration

Once deployed, the container automatically:

1. Generates a JWT token using the GitHub App credentials
2. Fetches an installation token for your organization
3. Registers the runner with GitHub Actions
4. Starts listening for jobs
5. Automatically deregisters when the container stops

### Scaling

The Container App is configured with:
- **Minimum replicas**: 1 (always one runner available)
- **Maximum replicas**: 10 (scales based on demand)
- **Consumption plan**: Pay only for what you use

### Monitoring

Monitor your runner through:
- **Azure Portal**: Container Apps logs and metrics
- **GitHub**: Organization/Repository settings → Actions → Runners

## Container Configuration

### Environment Variables

The container requires these environment variables (automatically set by Terraform):

- `APP_ID`: GitHub App ID (passed from GitHub variable)
- `APP_PRIVATE_KEY`: GitHub App private key (passed from GitHub secret)
- `GH_OWNER`: GitHub organization name (passed from GitHub variable)
- `RUNNER_NAME`: Unique runner instance name (passed from GitHub variable)

### Resource Allocation

Default resource allocation (configurable in `variables.tf`):
- **CPU**: 0.5 cores
- **Memory**: 1.0 GiB

## Security Considerations

- GitHub App private key is stored securely as a GitHub secret
- Runner uses organization-level registration (not personal access tokens)
- Azure resources are deployed with managed identity authentication
- Network isolation through dedicated virtual network
- Container runs with least-privilege access

## Troubleshooting

### Common Issues

1. **Runner fails to register**
   - Verify GitHub App has correct permissions
   - Check APP_ID and APP_PRIVATE_KEY are correctly set
   - Ensure GH_OWNER matches your organization name

2. **Container won't start**
   - Check Azure Container Apps logs in Azure Portal
   - Verify container image exists in registry
   - Confirm managed identity has ACR pull permissions

3. **Terraform deployment fails**
   - Verify Azure credentials and permissions
   - Check resource naming conflicts
   - Review Terraform state file location

### Useful Commands

```bash
# Check runner status
az containerapp logs show --resource-group <rg-name> --name <app-name>

# Restart container app
az containerapp revision restart --resource-group <rg-name> --name <app-name>

# View Terraform state
terraform show

# Force unlock Terraform state (if needed)
terraform force-unlock <lock-id>
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.