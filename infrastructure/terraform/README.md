# AKS Infrastructure as Code - Terraform Configuration

## 📋 Overview

This Terraform configuration manages the complete Azure Kubernetes Service (AKS) infrastructure for Rocket.Chat deployment, including networking, storage, security, and monitoring resources.

## 🔐 Authentication & Access

### Important: User Account Authentication

**This configuration is designed for user account authentication (not service principal):**

- ✅ **Azure Provider**: Uses default credentials from `az login`
- ✅ **Kubernetes Provider**: Uses kubeconfig file (no Azure AD integration required)
- ✅ **Helm Provider**: Uses same kubeconfig as Kubernetes provider

### Prerequisites

1. **Azure CLI** authenticated:
   ```bash
   az login
   az account set --subscription <your-subscription-id>  # Optional
   ```

2. **kubectl** configured with AKS cluster access:
   ```bash
   # Your kubeconfig should be available at:
   # - Linux/Mac: ~/.kube/config
   # - Windows: C:\Users\<user>\.kube\config
   # - Or set KUBECONFIG environment variable
   
   kubectl get nodes  # Verify access
   ```

3. **Terraform** >= 1.5 installed

## 🚀 Quick Start

### 1. Configure Backend Storage (One-Time Setup)

The Terraform state is stored in Azure Storage. Create the backend resources:

```bash
# Option 1: Use existing storage account (recommended)
# Set backend configuration via environment variables or backend.hcl

# Option 2: Create new storage account manually
az group create --name terraform-state-rg --location "UK South"
az storage account create \
  --name tfstate$(date +%s) \
  --resource-group terraform-state-rg \
  --location "UK South" \
  --sku Standard_LRS
az storage container create \
  --name tfstate \
  --account-name <storage-account-name>
```

### 2. Configure Variables

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# Key variables:
# - resource_group_name
# - cluster_name
# - environment (dev/staging/production)
# - kubeconfig_path (optional, auto-detected if not set)
```

### 3. Initialize Terraform

```bash
# Initialize with backend configuration
terraform init

# Or with backend config file
terraform init -backend-config=backend.hcl
```

### 4. Plan and Apply

```bash
# Review changes
terraform plan

# Apply configuration
terraform apply
```

## 📁 Configuration Structure

```
infrastructure/terraform/
├── providers.tf          # Provider configuration (Azure, Kubernetes, Helm)
├── versions.tf          # Version constraints (backwards compatibility)
├── variables.tf         # Input variables
├── locals.tf           # Local values and computed configurations
├── main.tf             # Main Azure infrastructure (AKS, VNet, Key Vault, Storage)
├── storage.tf          # Kubernetes Storage Classes and Volume Snapshots
├── outputs.tf          # Output values
├── terraform.tfvars.example  # Example variable values
└── README.md           # This file
```

## 🔧 Key Features

### Infrastructure Components

- **AKS Cluster**: Kubernetes cluster with system and user node pools
- **Networking**: Virtual Network, Subnet, NSG, Public IP
- **Storage**: Backup storage account, Kubernetes storage classes
- **Security**: Key Vault for secrets management
- **Monitoring**: Log Analytics workspace

### Node Pools

- **System Pool**: Kubernetes system components (auto-scaling: 1-3 nodes)
- **User Pool**: Application workloads (auto-scaling: 1-5 nodes)

### Storage Classes

- `premium-ssd`: High-performance storage (default)
- `standard-ssd`: Cost-optimized storage
- `standard-hdd`: Backup storage

### Volume Snapshots

- `premium-ssd-snapshot`: Default snapshot class
- `standard-ssd-snapshot`: Standard SSD snapshots

## 🌍 Environment Management

### Using Terraform Workspaces

```bash
# Create and switch to environment workspace
terraform workspace new dev
terraform workspace select dev

# Environment-specific variables can be set via:
# - terraform.tfvars (per workspace)
# - Environment variables (TF_VAR_*)
# - Command line flags (-var="environment=dev")
```

### Lifecycle Stages

The configuration supports lifecycle management:

- **active**: Full cluster with all services
- **suspended**: Cluster stopped, resources preserved
- **teardown**: Cluster destroyed, snapshots created

```bash
# Change lifecycle stage
terraform apply -var="lifecycle_stage=suspended"
```

## 🔒 Security Considerations

### Key Vault Access

- Current user (from `az login`) gets full access
- AKS cluster managed identity gets read-only access
- Additional users can be added via Azure Portal or CLI

### Network Security

- NSG rules for HTTPS (443), HTTP (80), SSH (22)
- Network policies enabled
- Private cluster option available (modify `main.tf`)

### SSH Access

Configure allowed source IPs:

```hcl
ssh_source_address_prefix = "YOUR_IP/32"  # Restrict SSH access
```

## 💰 Cost Optimization

### Auto-Scaling

- System nodes: 1-3 nodes (scales based on demand)
- User nodes: 1-5 nodes (scales based on workload)

### Spot Instances

Enable for cost savings (dev/staging environments):

```hcl
enable_spot_instances = true
spot_max_price       = 0.1
```

### VM Sizes

- Default: `Standard_DS2_v2` (2 vCPU, 7GB RAM)
- Override via variables: `system_node_size`, `user_node_size`

## 📊 Monitoring

### Log Analytics

- Workspace created automatically
- 30-day retention (configurable)
- OMS agent enabled on cluster

### Metrics

- Cluster performance metrics
- Resource utilization tracking
- Cost analysis and forecasting

## 🔄 Backup Integration

### Storage Accounts

- **Backups**: MongoDB backups and cluster state
- **Versioning**: Enabled with 30-day retention
- **Containers**: `mongodb-backups`, `cluster-state`

### Volume Snapshots

Use Kubernetes Volume Snapshots for PVC backups:

```bash
# Create snapshot
kubectl create volumesnapshot <snapshot-name> \
  --source=<pvc-name> \
  --volume-snapshot-class=premium-ssd-snapshot
```

## 🛠️ Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```bash
   # Verify Azure login
   az account show
   
   # Verify kubeconfig
   kubectl cluster-info
   ```

2. **Provider Configuration**
   ```bash
   # Kubernetes provider requires cluster to exist first
   # If you get "cluster not found" errors, ensure:
   # 1. Cluster is created in main.tf
   # 2. kubeconfig is properly configured
   # 3. Run terraform apply in correct order
   ```

3. **State Lock**
   ```bash
   # Check for concurrent operations
   az storage blob show \
     --account-name <storage-account> \
     --container-name tfstate \
     --name <state-file>.tflock
   ```

4. **Resource Conflicts**
   ```bash
   # Import existing resources
   terraform import azurerm_resource_group.main /subscriptions/.../resourceGroups/...
   ```

### Recovery Procedures

1. **State Corruption**: Restore from Azure Storage versioning
2. **Resource Deletion**: Use `terraform import` to re-add
3. **Configuration Drift**: Run `terraform plan` to identify differences

## 📝 Best Practices

1. **State Management**
   - Always use remote backend (Azure Storage)
   - Enable versioning on storage account
   - Regular state backups

2. **Variable Management**
   - Use `.tfvars` files (not committed to git)
   - Environment-specific configurations
   - Sensitive values via environment variables

3. **Resource Tagging**
   - Consistent tagging strategy (via `locals.tf`)
   - Cost tracking tags
   - Lifecycle management tags

4. **Version Control**
   - Commit only `.tf` files
   - Never commit `.tfstate` or `.tfvars` files
   - Use `.gitignore` for sensitive files

## 🔗 Integration

### CI/CD Pipelines

This configuration can be integrated with:
- GitHub Actions (using Azure CLI auth)
- Azure DevOps (using service connections)
- GitLab CI (using Azure credentials)

**Note**: Without service principal, CI/CD requires:
- Azure CLI authentication via managed identity (Azure VMs)
- Or manual `az login` token refresh

### Scripts Integration

The Terraform outputs integrate with:
- `scripts/lifecycle/` - Cluster lifecycle management
- `scripts/backup/` - Backup automation
- `scripts/monitoring/` - Monitoring setup

## 📚 Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Kubernetes Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)

## 🆘 Support

For issues and questions:
- Check Terraform documentation
- Review Azure AKS documentation
- Consult project troubleshooting guide: `docs/TROUBLESHOOTING_GUIDE.md`
