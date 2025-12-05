# Terraform Setup Guide

This guide will help you configure and deploy the RocketChat AKS infrastructure using Terraform.

## Prerequisites

- **Azure CLI** installed and authenticated (`az login`)
- **Terraform** >= 1.0 installed
- **Azure Subscription** with appropriate permissions
- **Domain names** configured and ready for DNS setup

## Quick Start

### 1. Configure Variables

```bash
cd infrastructure/terraform

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your actual values
nano terraform.tfvars  # or use your preferred editor
```

### 2. Required Configuration

At minimum, you **must** update these values in `terraform.tfvars`:

```hcl
# Azure Configuration
resource_group_name = "your-rg-name"      # e.g., "rocketchat-prod-rg"
cluster_name        = "your-cluster-name" # e.g., "rocketchat-aks"

# Domain Configuration  
rocketchat_domain = "chat.yourdomain.com"
grafana_domain    = "grafana.yourdomain.com"
```

### 3. Optional: Create Resource Group

If your resource group doesn't exist yet:

```bash
az group create \
  --name your-rg-name \
  --location eastus  # or your preferred region
```

### 4. Initialize Terraform

```bash
terraform init
```

### 5. Review Changes

```bash
terraform plan
```

### 6. Deploy Infrastructure

```bash
terraform apply
```

## Configuration Reference

### Environment Sizes

#### Development/Testing (~$50-100/month)
```hcl
environment         = "dev"
system_node_count   = 1
system_node_size    = "Standard_DS2_v2"
user_node_count     = 1
user_node_size      = "Standard_DS2_v2"
prevent_destroy     = false
```

#### Production (~$200-300/month)
```hcl
environment         = "production"
system_node_count   = 2
system_node_size    = "Standard_DS3_v2"
user_node_count     = 3
user_node_size      = "Standard_DS3_v2"
prevent_destroy     = true
```

### Security Best Practices

1. **SSH Access**: Restrict to your IP range
```hcl
ssh_source_address_prefix = "203.0.113.0/24"  # Your IP range
```

2. **Production Protection**: Enable prevent_destroy
```hcl
prevent_destroy = true
```

3. **Keep secrets secure**: Never commit `terraform.tfvars`
```bash
# Ensure it's in .gitignore
echo "terraform.tfvars" >> .gitignore
```

## Validation

Terraform includes built-in validation to prevent deployment with placeholder values:

```hcl
# This will fail:
resource_group_name = "<YOUR_RESOURCE_GROUP_NAME>"

# Error: Please set resource_group_name in terraform.tfvars - template placeholder detected.
```

Make sure to replace ALL `<YOUR_*>` placeholders before running `terraform apply`.

## Post-Deployment

After Terraform completes, you'll need to:

1. **Configure DNS**: Point your domains to the load balancer IP (shown in outputs)
2. **Deploy RocketChat**: Use Helm charts in `aks/deployment/`
3. **Set up Monitoring**: Deploy monitoring stack from `aks/monitoring/`

## Outputs

Terraform will output important values:

```bash
# View outputs
terraform output

# Get specific value
terraform output aks_cluster_name
terraform output load_balancer_ip
```

## State Management

### Backend Configuration (Recommended for Teams)

Uncomment and configure the backend in `main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "terraform-state-rg"
  storage_account_name = "tfstate<random>"
  container_name       = "tfstate"
  key                  = "aks-cluster.tfstate"
}
```

Then initialize:

```bash
terraform init -reconfigure
```

### Local State (Default)

By default, state is stored locally in `terraform.tfstate`. 

⚠️ **Important**: 
- Back up this file regularly
- Do NOT commit it to version control
- Consider using remote state for production

## Troubleshooting

### "Resource Group not found"

Ensure the resource group exists:
```bash
az group show --name your-rg-name
```

### "Subscription not found"

Check your Azure CLI subscription:
```bash
az account show
az account list
az account set --subscription "<subscription-id>"
```

### "Validation failed" errors

Replace all `<YOUR_*>` placeholders in `terraform.tfvars` with actual values.

### "Provider configuration is invalid"

Run terraform init:
```bash
terraform init -upgrade
```

## Common Commands

```bash
# Initialize
terraform init

# Format code
terraform fmt

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Show current state
terraform show

# List outputs
terraform output
```

## Cost Estimation

Before deploying, estimate costs:

1. Use Azure Pricing Calculator: https://azure.microsoft.com/pricing/calculator/
2. Review node pool sizes in your `terraform.tfvars`
3. Consider enabling auto-scaling and spot instances for cost savings

## Next Steps

After successful deployment:

1. ✅ Verify cluster access: `az aks get-credentials --resource-group <rg> --name <cluster>`
2. ✅ Configure DNS records for your domains
3. ✅ Deploy RocketChat: See `../../aks/deployment/README.md`
4. ✅ Set up monitoring: See `../../aks/monitoring/README.md`
5. ✅ Configure backups: See `../../scripts/backup/README.md`

## Support

- 📖 [Main README](../../README.md)
- 📖 [Deployment Guide](../../DEPLOYMENT_GUIDE.md)
- 📖 [Troubleshooting Guide](../../docs/TROUBLESHOOTING_GUIDE.md)
