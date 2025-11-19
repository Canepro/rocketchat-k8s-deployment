# Provider Configuration
# Configured for user account authentication (az login) and kubeconfig access

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration - set via backend.hcl or environment variables
  # Note: Backend must be configured before first terraform init
  backend "azurerm" {
    # Configure via:
    # 1. terraform init -backend-config=backend.hcl
    # 2. Environment variables (TF_BACKEND_RESOURCE_GROUP_NAME, etc.)
    # 3. Command line: terraform init -backend-config="resource_group_name=..."
  }
}

# Azure Provider - Uses default credentials from 'az login'
# No service principal required - works with user account authentication
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # Subscription ID - can be set via environment variable or here
  # subscription_id = var.subscription_id  # Optional: uncomment if needed
}

# Kubernetes Provider - Uses kubeconfig file
# Supports both Linux/Mac (~/.kube/config) and Windows paths
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context

  # Alternative: Use KUBECONFIG environment variable
  # config_path will be auto-detected if not specified
}

# Helm Provider - Uses same kubeconfig as Kubernetes provider
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

