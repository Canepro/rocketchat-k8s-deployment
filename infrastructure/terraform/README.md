# AKS Infrastructure as Code

This directory contains Terraform configurations for automated AKS cluster lifecycle management.

## Overview

The Terraform configuration creates:
- AKS cluster with system and user node pools
- Virtual network with proper subnetting
- Azure Key Vault for secrets management
- Storage accounts for backups and state
- Network security groups and load balancer
- Storage classes for different performance tiers

## Prerequisites

1. **Azure CLI** installed and authenticated
2. **Terraform** >= 1.0 installed
3. **kubectl** for cluster management
4. **Azure subscription** with appropriate permissions

## Quick Start

### 1. Configure Backend Storage

Create a storage account for Terraform state:

```bash
# Create resource group for Terraform state
az group create --name terraform-state-rg --location "UK South"

# Create storage account
az storage account create \
  --name tfstate$(date +%s) \
  --resource-group terraform-state-rg \
  --location "UK South" \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name <storage-account-name>
```

### 2. Configure Variables

Copy and customize the variables:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

## Configuration

### Key Variables

- `cluster_name`: Name of the AKS cluster
- `environment`: Environment (dev/staging/production)
- `lifecycle_stage`: Current stage (active/suspended/teardown)
- `auto_teardown_enabled`: Enable automatic teardown
- `enable_monitoring`: Deploy full monitoring stack

### Node Pools

- **System Pool**: Kubernetes system components
- **User Pool**: Application workloads (Rocket.Chat, MongoDB)

### Storage Classes

- `premium-ssd`: High-performance storage (default)
- `standard-ssd`: Cost-optimized storage
- `standard-hdd`: Backup storage

## Lifecycle Management

### Cluster States

1. **Active**: Full cluster with all services
2. **Suspended**: Cluster stopped, resources preserved
3. **Teardown**: Cluster destroyed, snapshots created

### State Transitions

```bash
# Suspend cluster (preserve resources)
terraform apply -var="lifecycle_stage=suspended"

# Resume cluster
terraform apply -var="lifecycle_stage=active"

# Teardown cluster (create snapshots first)
terraform apply -var="lifecycle_stage=teardown"
```

## Backup Integration

The Terraform configuration creates:
- Storage account for MongoDB backups
- Storage account for cluster state backups
- Key Vault for secrets management
- Snapshot classes for PVC backups

## Cost Optimization

### Resource Sizing

- System nodes: `Standard_DS2_v2` (2 vCPU, 7GB RAM)
- User nodes: `Standard_DS2_v2` (2 vCPU, 7GB RAM)
- Auto-scaling enabled for cost efficiency

### Spot Instances

Enable spot instances for cost savings:

```hcl
enable_spot_instances = true
spot_max_price       = 0.1
```

## Security

### Network Security

- Network policies enabled
- NSG rules for HTTPS/HTTP/SSH
- Private cluster option available

### Secrets Management

- Azure Key Vault integration
- Workload identity for automatic secret injection
- Encrypted storage for sensitive data

## Monitoring

### Log Analytics

- Centralized logging
- 30-day retention
- Cost tracking and optimization

### Metrics

- Cluster performance metrics
- Resource utilization tracking
- Cost analysis and forecasting

## Troubleshooting

### Common Issues

1. **State Lock**: Check for concurrent operations
2. **Permission Errors**: Verify Azure CLI authentication
3. **Resource Conflicts**: Check for existing resources

### Recovery Procedures

1. **State Corruption**: Restore from backup
2. **Resource Deletion**: Use `terraform import`
3. **Configuration Drift**: Run `terraform plan` to identify

## Automation Integration

### CI/CD Pipelines

The Terraform configuration integrates with:
- GitHub Actions workflows
- Azure DevOps pipelines
- Automated backup scripts
- Cost monitoring systems

### Scripts Integration

- `scripts/lifecycle/teardown-cluster.sh`
- `scripts/lifecycle/recreate-cluster.sh`
- `scripts/backup/create-pvc-snapshots.sh`

## Outputs

Key outputs for automation:
- `cluster_name`: Cluster identifier
- `public_ip_address`: Load balancer IP
- `storage_account_name`: Backup storage
- `key_vault_name`: Secrets management
- `kubectl_config`: Connection command

## Best Practices

1. **State Management**: Use remote backend
2. **Variable Management**: Use `.tfvars` files
3. **Resource Tagging**: Consistent tagging strategy
4. **Backup Strategy**: Regular state backups
5. **Cost Monitoring**: Track resource costs

## Support

For issues and questions:
- Check Terraform documentation
- Review Azure AKS documentation
- Consult project troubleshooting guide
