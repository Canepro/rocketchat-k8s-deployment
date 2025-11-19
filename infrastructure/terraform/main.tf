# AKS Cluster Infrastructure as Code
# Terraform configuration for automated cluster lifecycle management

# Terraform and provider configuration moved to providers.tf
# This file now focuses on Azure infrastructure resources

# Data sources
data "azurerm_client_config" "current" {}
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_size
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = local.node_pool_configs.system.min_count
    max_count           = local.node_pool_configs.system.max_count

    # Node labels
    node_labels = local.node_pool_configs.system.node_labels

    # Enable node auto-repair and auto-upgrade
    # Note: auto_repair_enabled and auto_upgrade_enabled are cluster-level settings
  }

  # Identity configuration
  identity {
    type = "SystemAssigned"
  }

  # Network profile
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  # Monitoring addon (deprecated addon_profile replaced with oms_agent block)
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # HTTP Application Routing (disabled by default for security)
  http_application_routing_enabled = false

  # Tags for cost tracking and lifecycle management
  tags = local.common_tags
}

# Azure Resource Lock to prevent accidental deletion
# Note: Terraform lifecycle.prevent_destroy cannot use variables
# Using Azure Resource Lock instead for variable-controlled protection
resource "azurerm_management_lock" "cluster" {
  count      = var.prevent_destroy ? 1 : 0
  name       = "${var.cluster_name}-lock"
  scope      = azurerm_kubernetes_cluster.main.id
  lock_level = "CanNotDelete"
  
  notes = "Prevent accidental cluster deletion - managed by Terraform"
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.cluster_name}-logs"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.cluster_name}-vnet"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]

  tags = local.common_tags
}

# AKS Subnet
resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.cluster_name}-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# Network Security Group for AKS
resource "azurerm_network_security_group" "aks" {
  name                = "${var.cluster_name}-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  # Allow inbound HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow inbound HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow SSH for debugging
  security_rule {
    name                       = "AllowSSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_address_prefix
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# Static Public IP for Load Balancer
resource "azurerm_public_ip" "aks_lb" {
  name                = "${var.cluster_name}-lb-ip"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  # Preserve IP during teardown/recreation cycles
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    PreserveIP = "true"
  })
}

# Azure Key Vault for secrets management
resource "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Access policies - Using Azure RBAC (modern approach)
  # For user account access, you'll be added via Azure Portal or CLI
  # Alternative: use access_policy blocks for legacy support

  # Current user access (from az login)
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }

  # AKS cluster managed identity access
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_kubernetes_cluster.main.identity[0].principal_id

    secret_permissions = [
      "Get", "List"
    ]
  }

  # Enable soft delete and purge protection
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = local.common_tags
}

# Storage Account for backups
resource "azurerm_storage_account" "backups" {
  name                     = local.storage_account_name
  location                 = data.azurerm_resource_group.main.location
  resource_group_name      = data.azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Enable versioning for backup retention
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }

  tags = merge(local.common_tags, {
    Purpose = "backups"
  })
}

# Container for MongoDB backups
resource "azurerm_storage_container" "mongodb_backups" {
  name                  = "mongodb-backups"
  storage_account_name  = azurerm_storage_account.backups.name
  container_access_type = "private"
}

# Container for cluster state backups
resource "azurerm_storage_container" "cluster_state" {
  name                  = "cluster-state"
  storage_account_name  = azurerm_storage_account.backups.name
  container_access_type = "private"
}

# User Node Pool (separate from default system pool)
# Must be created as separate resource - cannot be defined inline in cluster resource
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_size
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id
  node_count            = var.user_node_count

  # Auto-scaling configuration
  enable_auto_scaling = true
  min_count           = local.node_pool_configs.user.min_count
  max_count           = local.node_pool_configs.user.max_count

  # Node pool type
  type = "VirtualMachineScaleSets"

  # Node labels and taints
  node_labels = local.node_pool_configs.user.node_labels
  node_taints = local.node_pool_configs.user.node_taints

  # OS configuration
  os_type         = "Linux"
  os_disk_type    = "Managed"
  os_disk_size_gb = 128

  # Spot instances (optional, for cost optimization)
  priority        = var.enable_spot_instances ? "Spot" : "Regular"
  eviction_policy = var.enable_spot_instances ? "Delete" : null
  spot_max_price  = var.enable_spot_instances ? var.spot_max_price : null

  # Lifecycle - prevent accidental deletion
  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}
