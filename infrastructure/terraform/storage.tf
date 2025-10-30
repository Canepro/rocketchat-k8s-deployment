# Storage Configuration for AKS Cluster
# Storage classes, disk configurations, and backup storage

# Storage Account for Terraform state
resource "azurerm_storage_account" "terraform_state" {
  name                     = "tfstate${random_string.terraform_suffix.result}"
  location                 = data.azurerm_resource_group.main.location
  resource_group_name      = data.azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Enable versioning for state file protection
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }

  tags = {
    Environment = var.environment
    Project     = "rocketchat-k8s"
    Purpose     = "terraform-state"
  }
}

# Container for Terraform state
resource "azurerm_storage_container" "terraform_state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"
}

# Random string for Terraform state storage account
resource "random_string" "terraform_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Storage Class for Premium SSD
resource "azurerm_kubernetes_cluster" "main" {
  # ... (existing configuration from main.tf)
  
  # Storage profile for dynamic provisioning
  storage_profile {
    file_driver_enabled = true
    disk_driver_enabled = true
    snapshot_controller_enabled = true
  }
}

# Kubernetes Storage Class for Premium SSD
resource "kubernetes_storage_class" "premium_ssd" {
  depends_on = [azurerm_kubernetes_cluster.main]
  
  metadata {
    name = "premium-ssd"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  
  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy          = "Retain"
  volume_binding_mode     = "WaitForFirstConsumer"
  allow_volume_expansion  = true
  
  parameters = {
    skuname = "Premium_LRS"
    cachingmode = "ReadWrite"
    kind = "Managed"
  }
}

# Kubernetes Storage Class for Standard SSD (cost optimization)
resource "kubernetes_storage_class" "standard_ssd" {
  depends_on = [azurerm_kubernetes_cluster.main]
  
  metadata {
    name = "standard-ssd"
  }
  
  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy          = "Retain"
  volume_binding_mode     = "WaitForFirstConsumer"
  allow_volume_expansion  = true
  
  parameters = {
    skuname = "StandardSSD_LRS"
    cachingmode = "ReadWrite"
    kind = "Managed"
  }
}

# Kubernetes Storage Class for HDD (backup storage)
resource "kubernetes_storage_class" "standard_hdd" {
  depends_on = [azurerm_kubernetes_cluster.main]
  
  metadata {
    name = "standard-hdd"
  }
  
  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy          = "Retain"
  volume_binding_mode     = "WaitForFirstConsumer"
  allow_volume_expansion  = false
  
  parameters = {
    skuname = "Standard_LRS"
    cachingmode = "None"
    kind = "Managed"
  }
}

# Snapshot Class for PVC snapshots
resource "kubernetes_volume_snapshot_class" "premium_ssd_snapshot" {
  depends_on = [azurerm_kubernetes_cluster.main]
  
  metadata {
    name = "premium-ssd-snapshot"
    annotations = {
      "snapshot.storage.kubernetes.io/is-default-class" = "true"
    }
  }
  
  driver         = "disk.csi.azure.com"
  deletion_policy = "Delete"
  
  parameters = {
    skuname = "Premium_LRS"
  }
}

# Snapshot Class for Standard SSD snapshots
resource "kubernetes_volume_snapshot_class" "standard_ssd_snapshot" {
  depends_on = [azurerm_kubernetes_cluster.main]
  
  metadata {
    name = "standard-ssd-snapshot"
  }
  
  driver         = "disk.csi.azure.com"
  deletion_policy = "Delete"
  
  parameters = {
    skuname = "StandardSSD_LRS"
  }
}
