# Terraform Variables for AKS Cluster
# Parameterized configuration for different environments

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rocketchat-k8s-rg"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "rocketchat-aks"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "lifecycle_stage" {
  description = "Current lifecycle stage (active, suspended, teardown)"
  type        = string
  default     = "active"
  
  validation {
    condition     = contains(["active", "suspended", "teardown"], var.lifecycle_stage)
    error_message = "Lifecycle stage must be one of: active, suspended, teardown."
  }
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "rocketchat"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.28"
}

# Node pool configurations
variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 1
}

variable "system_node_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "user_node_count" {
  description = "Number of nodes in the user node pool"
  type        = number
  default     = 2
}

variable "user_node_size" {
  description = "VM size for user nodes"
  type        = string
  default     = "Standard_DS2_v2"
}

# Network configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR block for the AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for the Kubernetes DNS service"
  type        = string
  default     = "10.1.0.10"
}

# Security configuration
variable "ssh_source_address_prefix" {
  description = "Source address prefix for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

# Lifecycle management
variable "auto_teardown_enabled" {
  description = "Enable automatic teardown during billing cycles"
  type        = bool
  default     = true
}

variable "prevent_destroy" {
  description = "Prevent accidental destruction of the cluster"
  type        = bool
  default     = false
}

# Cost optimization
variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Maximum price for spot instances (in USD per hour)"
  type        = number
  default     = 0.1
}

# Monitoring configuration
variable "enable_monitoring" {
  description = "Enable full monitoring stack deployment"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

# Backup configuration
variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "snapshot_retention_days" {
  description = "Number of days to retain disk snapshots"
  type        = number
  default     = 7
}

# Domain configuration
variable "rocketchat_domain" {
  description = "Domain name for Rocket.Chat"
  type        = string
  default     = "chat.canepro.me"
}

variable "grafana_domain" {
  description = "Domain name for Grafana"
  type        = string
  default     = "grafana.chat.canepro.me"
}

# Resource tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
