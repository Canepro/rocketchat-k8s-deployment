# Local Values
# Centralized configuration and computed values for DRY principles

locals {
  # Common tags applied to all resources
  common_tags = merge(
    {
      Environment    = var.environment
      Project        = "rocketchat-k8s"
      ManagedBy      = "terraform"
      CostCenter     = "development"
      LifecycleStage = var.lifecycle_stage
      BackupEnabled  = "true"
      AutoTeardown   = var.auto_teardown_enabled ? "true" : "false"
    },
    var.additional_tags
  )

  # Resource naming prefix
  resource_prefix = "${var.cluster_name}-${var.environment}"

  # Environment-specific node pool configurations
  # These can be overridden via variables, but provide sensible defaults
  node_pool_configs = {
    system = {
      vm_size   = var.system_node_size
      min_count = 1
      max_count = 3
      node_labels = {
        "pool" = "system"
      }
      node_taints = []
    }
    user = {
      vm_size   = var.user_node_size
      min_count = 1
      max_count = 5
      node_labels = {
        "workload"    = "rocketchat"
        "environment" = var.environment
        "pool"        = "user"
      }
      node_taints = []
    }
  }

  # Cost optimization: Different VM sizes based on environment
  # Override via variables if needed
  cost_optimized_vm_sizes = {
    dev        = "Standard_B2s"    # Burstable, cheaper
    staging    = "Standard_DS2_v2" # Standard
    production = "Standard_DS2_v2" # Standard (can upgrade to DS3_v2 for production)
  }

  # Network CIDR validation helpers
  # Ensure no overlap between VNet, subnet, and service CIDR
  network_config = {
    vnet_cidr      = var.vnet_address_space
    subnet_cidr    = var.aks_subnet_cidr
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  # Key Vault naming (must be globally unique)
  key_vault_name = "${replace(var.cluster_name, "-", "")}kv${random_string.suffix.result}"

  # Storage account naming (must be globally unique, lowercase, no hyphens)
  storage_account_name = "${replace(lower(var.cluster_name), "-", "")}backups${random_string.suffix.result}"

  # Random suffix for globally unique resource names
  random_suffix = random_string.suffix.result
}

# Random string for unique resource naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
  lower   = true
}

