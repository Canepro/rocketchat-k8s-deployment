# Terraform Outputs for AKS Cluster
# Essential information for automation scripts and CI/CD pipelines

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "cluster_private_fqdn" {
  description = "Private FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.private_fqdn
}

output "cluster_identity" {
  description = "Managed identity of the AKS cluster"
  value = {
    principal_id = azurerm_kubernetes_cluster.main.identity[0].principal_id
    tenant_id    = azurerm_kubernetes_cluster.main.identity[0].tenant_id
  }
}

output "kube_config" {
  description = "Kubernetes configuration for the cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "host" {
  description = "Kubernetes cluster server host"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive   = true
}

output "client_key" {
  description = "Kubernetes cluster client key"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_key
  sensitive   = true
}

output "client_certificate" {
  description = "Kubernetes cluster client certificate"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

# Network outputs
output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks_subnet.id
}

output "subnet_name" {
  description = "Name of the AKS subnet"
  value       = azurerm_subnet.aks_subnet.name
}

output "public_ip_id" {
  description = "ID of the public IP for load balancer"
  value       = azurerm_public_ip.aks_lb.id
}

output "public_ip_address" {
  description = "Public IP address for load balancer"
  value       = azurerm_public_ip.aks_lb.ip_address
}

output "public_ip_fqdn" {
  description = "FQDN of the public IP"
  value       = azurerm_public_ip.aks_lb.fqdn
}

# Storage outputs
output "storage_account_name" {
  description = "Name of the storage account for backups"
  value       = azurerm_storage_account.backups.name
}

output "storage_account_id" {
  description = "ID of the storage account for backups"
  value       = azurerm_storage_account.backups.id
}

output "storage_account_primary_key" {
  description = "Primary key of the storage account"
  value       = azurerm_storage_account.backups.primary_access_key
  sensitive   = true
}

output "mongodb_backup_container" {
  description = "Name of the MongoDB backup container"
  value       = azurerm_storage_container.mongodb_backups.name
}

output "cluster_state_container" {
  description = "Name of the cluster state backup container"
  value       = azurerm_storage_container.cluster_state.name
}

# Key Vault outputs
output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

# Log Analytics outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

# Resource group information
output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = data.azurerm_resource_group.main.location
}

# Node pool information
output "system_node_pool" {
  description = "System node pool information"
  value = {
    name       = azurerm_kubernetes_cluster.main.default_node_pool[0].name
    node_count = azurerm_kubernetes_cluster.main.default_node_pool[0].node_count
    vm_size    = azurerm_kubernetes_cluster.main.default_node_pool[0].vm_size
  }
}

output "user_node_pool" {
  description = "User node pool information"
  value = {
    name       = azurerm_kubernetes_cluster.main.node_pool[0].name
    node_count = azurerm_kubernetes_cluster.main.node_pool[0].node_count
    vm_size    = azurerm_kubernetes_cluster.main.node_pool[0].vm_size
  }
}

# Environment information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "lifecycle_stage" {
  description = "Current lifecycle stage"
  value       = var.lifecycle_stage
}

# Connection information for automation scripts
output "kubectl_config" {
  description = "Kubectl configuration command"
  value       = "az aks get-credentials --resource-group ${data.azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  value       = "https://${azurerm_kubernetes_cluster.main.fqdn}"
}

# Cost tracking information
output "cost_tags" {
  description = "Tags for cost tracking"
  value = {
    Environment     = var.environment
    Project         = "rocketchat-k8s"
    LifecycleStage  = var.lifecycle_stage
    CostCenter      = "development"
    ManagedBy       = "terraform"
  }
}
