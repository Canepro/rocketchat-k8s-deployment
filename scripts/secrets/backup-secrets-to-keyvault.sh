#!/bin/bash
# Backup Kubernetes Secrets to Azure Key Vault
# Backs up all secrets from Kubernetes to Azure Key Vault before teardown

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_status "🔐 Backing up Kubernetes secrets to Azure Key Vault"

# Configuration
KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rocketchat-k8s-rg}"
ROCKETCHAT_NAMESPACE="${ROCKETCHAT_NAMESPACE:-rocketchat}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Please run 'az login'."
        exit 1
    fi
    
    # Check Key Vault access
    if ! az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        print_error "Cannot access Key Vault '$KEY_VAULT_NAME'. Check permissions."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Backup MongoDB secrets
backup_mongodb_secrets() {
    print_status "Backing up MongoDB secrets..."
    
    # Get MongoDB auth secret
    if kubectl get secret mongodb-auth -n "$ROCKETCHAT_NAMESPACE" &> /dev/null; then
        MONGODB_USERNAME=$(kubectl get secret mongodb-auth -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.username}' | base64 -d)
        MONGODB_PASSWORD=$(kubectl get secret mongodb-auth -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
        MONGODB_ROOT_PASSWORD=$(kubectl get secret mongodb-auth -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.root-password}' | base64 -d)
        
        # Store in Key Vault
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongodb-username" --value "$MONGODB_USERNAME" &> /dev/null
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongodb-password" --value "$MONGODB_PASSWORD" &> /dev/null
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongodb-root-password" --value "$MONGODB_ROOT_PASSWORD" &> /dev/null
        
        print_success "MongoDB secrets backed up"
    else
        print_warning "MongoDB auth secret not found in namespace '$ROCKETCHAT_NAMESPACE'"
    fi
}

# Backup Rocket.Chat secrets
backup_rocketchat_secrets() {
    print_status "Backing up Rocket.Chat secrets..."
    
    # Get Rocket.Chat MongoDB auth secret
    if kubectl get secret rocketchat-mongodb-auth -n "$ROCKETCHAT_NAMESPACE" &> /dev/null; then
        MONGO_URL=$(kubectl get secret rocketchat-mongodb-auth -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.mongo-url}' | base64 -d)
        MONGO_OPLOG_URL=$(kubectl get secret rocketchat-mongodb-auth -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.mongo-oplog-url}' | base64 -d)
        
        # Store in Key Vault
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongo-url" --value "$MONGO_URL" &> /dev/null
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongo-oplog-url" --value "$MONGO_OPLOG_URL" &> /dev/null
        
        print_success "Rocket.Chat MongoDB secrets backed up"
    else
        print_warning "Rocket.Chat MongoDB auth secret not found in namespace '$ROCKETCHAT_NAMESPACE'"
    fi
    
    # Get Rocket.Chat admin secret
    if kubectl get secret rocketchat-admin -n "$ROCKETCHAT_NAMESPACE" &> /dev/null; then
        ROCKETCHAT_ADMIN_USER=$(kubectl get secret rocketchat-admin -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.username}' | base64 -d)
        ROCKETCHAT_ADMIN_PASSWORD=$(kubectl get secret rocketchat-admin -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
        
        # Store in Key Vault
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "rocketchat-admin-user" --value "$ROCKETCHAT_ADMIN_USER" &> /dev/null
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "rocketchat-admin-password" --value "$ROCKETCHAT_ADMIN_PASSWORD" &> /dev/null
        
        print_success "Rocket.Chat admin secrets backed up"
    else
        print_warning "Rocket.Chat admin secret not found in namespace '$ROCKETCHAT_NAMESPACE'"
    fi
}

# Backup monitoring secrets
backup_monitoring_secrets() {
    print_status "Backing up monitoring secrets..."
    
    # Get Grafana admin secret
    if kubectl get secret grafana-admin -n "$MONITORING_NAMESPACE" &> /dev/null; then
        GRAFANA_ADMIN_USER=$(kubectl get secret grafana-admin -n "$MONITORING_NAMESPACE" -o jsonpath='{.data.username}' | base64 -d)
        GRAFANA_ADMIN_PASSWORD=$(kubectl get secret grafana-admin -n "$MONITORING_NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
        
        # Store in Key Vault
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "grafana-admin-user" --value "$GRAFANA_ADMIN_USER" &> /dev/null
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "grafana-admin-password" --value "$GRAFANA_ADMIN_PASSWORD" &> /dev/null
        
        print_success "Grafana admin secrets backed up"
    else
        print_warning "Grafana admin secret not found in namespace '$MONITORING_NAMESPACE'"
    fi
    
    # Get SMTP secret
    if kubectl get secret alertmanager-smtp -n "$MONITORING_NAMESPACE" &> /dev/null; then
        SMTP_USERNAME=$(kubectl get secret alertmanager-smtp -n "$MONITORING_NAMESPACE" -o jsonpath='{.data.username}' | base64 -d)
        SMTP_PASSWORD=$(kubectl get secret alertmanager-smtp -n "$MONITORING_NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
        
        # Store in Key Vault
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "smtp-username" --value "$SMTP_USERNAME" &> /dev/null
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "smtp-password" --value "$SMTP_PASSWORD" &> /dev/null
        
        print_success "SMTP secrets backed up"
    else
        print_warning "SMTP secret not found in namespace '$MONITORING_NAMESPACE'"
    fi
    
    # Get webhook secret
    if kubectl get secret alertmanager-webhook -n "$MONITORING_NAMESPACE" &> /dev/null; then
        WEBHOOK_URL=$(kubectl get secret alertmanager-webhook -n "$MONITORING_NAMESPACE" -o jsonpath='{.data.webhook-url}' | base64 -d)
        EMAIL_RECIPIENT=$(kubectl get secret alertmanager-webhook -n "$MONITORING_NAMESPACE" -o jsonpath='{.data.email-recipient}' | base64 -d)
        
        # Store in Key Vault
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "rocketchat-webhook-url" --value "$WEBHOOK_URL" &> /dev/null
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "alert-email-recipient" --value "$EMAIL_RECIPIENT" &> /dev/null
        
        print_success "Webhook secrets backed up"
    else
        print_warning "Webhook secret not found in namespace '$MONITORING_NAMESPACE'"
    fi
}

# Backup SSL certificate secrets
backup_ssl_secrets() {
    print_status "Backing up SSL certificate secrets..."
    
    # Get Rocket.Chat SSL certificate
    if kubectl get secret rocketchat-tls -n "$ROCKETCHAT_NAMESPACE" &> /dev/null; then
        SSL_CERT=$(kubectl get secret rocketchat-tls -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d)
        SSL_KEY=$(kubectl get secret rocketchat-tls -n "$ROCKETCHAT_NAMESPACE" -o jsonpath='{.data.tls\.key}' | base64 -d)
        
        # Store in Key Vault
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "ssl-certificate" --value "$SSL_CERT" &> /dev/null
        az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "ssl-private-key" --value "$SSL_KEY" &> /dev/null
        
        print_success "SSL certificate secrets backed up"
    else
        print_warning "SSL certificate secret not found in namespace '$ROCKETCHAT_NAMESPACE'"
    fi
}

# Verify backup
verify_backup() {
    print_status "Verifying backup in Azure Key Vault..."
    
    # List secrets in Key Vault
    print_status "Secrets in Key Vault '$KEY_VAULT_NAME':"
    az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "[].name" -o table
    
    print_success "Backup verification completed"
}

# Main execution
main() {
    print_status "Starting Kubernetes secrets backup to Azure Key Vault..."
    
    check_prerequisites
    backup_mongodb_secrets
    backup_rocketchat_secrets
    backup_monitoring_secrets
    backup_ssl_secrets
    verify_backup
    
    print_success "Kubernetes secrets backup to Azure Key Vault completed successfully!"
    echo ""
    echo "🔐 Backed up secrets:"
    echo "   • MongoDB authentication credentials"
    echo "   • Rocket.Chat admin credentials"
    echo "   • Grafana admin credentials"
    echo "   • SMTP credentials for alerting"
    echo "   • SSL certificates"
    echo "   • Webhook URLs"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Proceed with cluster teardown"
    echo "   2. Secrets will be restored during cluster recreation"
    echo "   3. Use sync-from-keyvault.sh to restore secrets"
}

# Run main function
main "$@"
