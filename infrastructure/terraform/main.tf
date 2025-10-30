# AKS Cluster Infrastructure as Code
# Terraform configuration for automated cluster lifecycle management

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  backend "azurerm" {
    # Configure backend in terraform.tfvars or via environment variables
    # resource_group_name  = "terraform-state-rg"
    # storage_account_name = "tfstate<random>"
    # container_name       = "tfstate"
    # key                  = "aks-cluster.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

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
    node_count         = var.system_node_count
    vm_size            = var.system_node_size
    vnet_subnet_id     = azurerm_subnet.aks_subnet.id
    type               = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count          = 1
    max_count          = 3
    
    # Enable node auto-repair and auto-upgrade
    auto_scaling_enabled = true
    auto_repair_enabled  = true
    auto_upgrade_enabled = true
  }

  # User node pool for workloads
  node_pool {
    name                = "user"
    node_count          = var.user_node_count
    vm_size            = var.user_node_size
    vnet_subnet_id     = azurerm_subnet.aks_subnet.id
    type               = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count          = 1
    max_count          = 5
    
    # Node pool labels and taints
    node_labels = {
      "workload" = "rocketchat"
      "environment" = var.environment
    }
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

  # Add-ons
  addon_profile {
    http_application_routing {
      enabled = false
    }
    
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
    }
  }

  # Tags for cost tracking and lifecycle management
  tags = {
    Environment     = var.environment
    Project         = "rocketchat-k8s"
    LifecycleStage  = var.lifecycle_stage
    CostCenter      = "development"
    ManagedBy       = "terraform"
    BackupEnabled   = "true"
    AutoTeardown    = var.auto_teardown_enabled ? "true" : "false"
  }

  lifecycle {
    prevent_destroy = var.prevent_destroy
  }
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.cluster_name}-logs"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = var.environment
    Project     = "rocketchat-k8s"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.cluster_name}-vnet"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]

  tags = {
    Environment = var.environment
    Project     = "rocketchat-k8s"
  }
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
    source_address_prefix        = var.ssh_source_address_prefix
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    Project     = "rocketchat-k8s"
  }
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

  tags = {
    Environment     = var.environment
    Project         = "rocketchat-k8s"
    PreserveIP     = "true"
    LifecycleStage  = var.lifecycle_stage
  }
}

# Azure Key Vault for secrets management
resource "azurerm_key_vault" "main" {
  name                = "${var.cluster_name}-kv-${random_string.suffix.result}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Access policies
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }

  # AKS cluster access
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

  tags = {
    Environment = var.environment
    Project     = "rocketchat-k8s"
  }
}

# Random string for Key Vault name uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Storage Account for backups
resource "azurerm_storage_account" "backups" {
  name                     = "${var.cluster_name}backups${random_string.suffix.result}"
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

  tags = {
    Environment = var.environment
    Project     = "rocketchat-k8s"
    Purpose     = "backups"
  }
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
