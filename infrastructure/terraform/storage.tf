# Storage Configuration for AKS Cluster
# Kubernetes Storage Classes and Volume Snapshot Classes
# Note: Storage account for backups is defined in main.tf

# Kubernetes Storage Class for Premium SSD (default)
resource "kubernetes_storage_class" "premium_ssd" {
  depends_on = [azurerm_kubernetes_cluster.main]

  metadata {
    name = "premium-ssd"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    skuname     = "Premium_LRS"
    cachingmode = "ReadWrite"
    kind        = "Managed"
  }
}

# Kubernetes Storage Class for Standard SSD (cost optimization)
resource "kubernetes_storage_class" "standard_ssd" {
  depends_on = [azurerm_kubernetes_cluster.main]

  metadata {
    name = "standard-ssd"
  }

  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    skuname     = "StandardSSD_LRS"
    cachingmode = "ReadWrite"
    kind        = "Managed"
  }
}

# Kubernetes Storage Class for HDD (backup storage)
resource "kubernetes_storage_class" "standard_hdd" {
  depends_on = [azurerm_kubernetes_cluster.main]

  metadata {
    name = "standard-hdd"
  }

  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = false

  parameters = {
    skuname     = "Standard_LRS"
    cachingmode = "None"
    kind        = "Managed"
  }
}

# Volume Snapshot Class for Premium SSD PVC snapshots
resource "kubernetes_volume_snapshot_class" "premium_ssd_snapshot" {
  depends_on = [azurerm_kubernetes_cluster.main]

  metadata {
    name = "premium-ssd-snapshot"
    annotations = {
      "snapshot.storage.kubernetes.io/is-default-class" = "true"
    }
  }

  driver          = "disk.csi.azure.com"
  deletion_policy = "Delete"

  parameters = {
    skuname = "Premium_LRS"
  }
}

# Volume Snapshot Class for Standard SSD PVC snapshots
resource "kubernetes_volume_snapshot_class" "standard_ssd_snapshot" {
  depends_on = [azurerm_kubernetes_cluster.main]

  metadata {
    name = "standard-ssd-snapshot"
  }

  driver          = "disk.csi.azure.com"
  deletion_policy = "Delete"

  parameters = {
    skuname = "StandardSSD_LRS"
  }
}
