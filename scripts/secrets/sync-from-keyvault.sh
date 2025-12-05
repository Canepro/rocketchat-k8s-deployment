#!/bin/bash
# Azure Key Vault Secrets Sync Script
# Syncs secrets from Azure Key Vault to Kubernetes cluster

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

print_status "🔐 Syncing secrets from Azure Key Vault to Kubernetes"

# Configuration
KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
RESOURCE_GROUP="${RESOURCE_GROUP:-<YOUR_RESOURCE_GROUP>}"
NAMESPACE="${NAMESPACE:-rocketchat}"

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

# Create namespace if it doesn't exist
create_namespace() {
    print_status "Creating namespace '$NAMESPACE' if it doesn't exist..."
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace '$NAMESPACE' ready"
}

# Sync MongoDB secrets
sync_mongodb_secrets() {
    print_status "Syncing MongoDB secrets..."
    
    # Get MongoDB root password
    MONGODB_ROOT_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "mongodb-root-password" --query "value" -o tsv)
    
    # Get MongoDB user credentials
    MONGODB_USERNAME=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "mongodb-username" --query "value" -o tsv)
    MONGODB_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "mongodb-password" --query "value" -o tsv)
    
    # Create MongoDB auth secret
    kubectl create secret generic mongodb-auth \
        --namespace="$NAMESPACE" \
        --from-literal=username="$MONGODB_USERNAME" \
        --from-literal=password="$MONGODB_PASSWORD" \
        --from-literal=root-password="$MONGODB_ROOT_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "MongoDB secrets synced"
}

# Sync Rocket.Chat secrets
sync_rocketchat_secrets() {
    print_status "Syncing Rocket.Chat secrets..."
    
    # Get Rocket.Chat admin credentials
    ROCKETCHAT_ADMIN_USER=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "rocketchat-admin-user" --query "value" -o tsv)
    ROCKETCHAT_ADMIN_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "rocketchat-admin-password" --query "value" -o tsv)
    
    # Get MongoDB connection strings
    MONGO_URL=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "mongo-url" --query "value" -o tsv)
    MONGO_OPLOG_URL=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "mongo-oplog-url" --query "value" -o tsv)
    
    # Create Rocket.Chat MongoDB auth secret
    kubectl create secret generic rocketchat-mongodb-auth \
        --namespace="$NAMESPACE" \
        --from-literal=mongo-url="$MONGO_URL" \
        --from-literal=mongo-oplog-url="$MONGO_OPLOG_URL" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Rocket.Chat admin secret
    kubectl create secret generic rocketchat-admin \
        --namespace="$NAMESPACE" \
        --from-literal=username="$ROCKETCHAT_ADMIN_USER" \
        --from-literal=password="$ROCKETCHAT_ADMIN_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Rocket.Chat secrets synced"
}

# Sync monitoring secrets
sync_monitoring_secrets() {
    print_status "Syncing monitoring secrets..."
    
    # Get Grafana admin credentials
    GRAFANA_ADMIN_USER=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "grafana-admin-user" --query "value" -o tsv)
    GRAFANA_ADMIN_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "grafana-admin-password" --query "value" -o tsv)
    
    # Get SMTP credentials
    SMTP_USERNAME=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "smtp-username" --query "value" -o tsv)
    SMTP_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "smtp-password" --query "value" -o tsv)
    
    # Get webhook URLs
    ROCKETCHAT_WEBHOOK_URL=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "rocketchat-webhook-url" --query "value" -o tsv)
    ALERT_EMAIL_RECIPIENT=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "alert-email-recipient" --query "value" -o tsv)
    
    # Create Grafana admin secret
    kubectl create secret generic grafana-admin \
        --namespace="monitoring" \
        --from-literal=username="$GRAFANA_ADMIN_USER" \
        --from-literal=password="$GRAFANA_ADMIN_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create SMTP secret
    kubectl create secret generic alertmanager-smtp \
        --namespace="monitoring" \
        --from-literal=username="$SMTP_USERNAME" \
        --from-literal=password="$SMTP_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create webhook secret
    kubectl create secret generic alertmanager-webhook \
        --namespace="monitoring" \
        --from-literal=webhook-url="$ROCKETCHAT_WEBHOOK_URL" \
        --from-literal=email-recipient="$ALERT_EMAIL_RECIPIENT" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "Monitoring secrets synced"
}

# Sync SSL certificate secrets
sync_ssl_secrets() {
    print_status "Syncing SSL certificate secrets..."
    
    # Get SSL certificate and key
    SSL_CERT=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "ssl-certificate" --query "value" -o tsv)
    SSL_KEY=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "ssl-private-key" --query "value" -o tsv)
    
    # Create SSL certificate secret
    kubectl create secret tls rocketchat-tls \
        --namespace="$NAMESPACE" \
        --cert=<(echo "$SSL_CERT") \
        --key=<(echo "$SSL_KEY") \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Grafana SSL certificate secret
    kubectl create secret tls grafana-tls \
        --namespace="monitoring" \
        --cert=<(echo "$SSL_CERT") \
        --key=<(echo "$SSL_KEY") \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_success "SSL certificate secrets synced"
}

# Verify secrets
verify_secrets() {
    print_status "Verifying synced secrets..."
    
    # Check Rocket.Chat namespace secrets
    print_status "Rocket.Chat namespace secrets:"
    kubectl get secrets -n "$NAMESPACE" | grep -E "(mongodb-auth|rocketchat-mongodb-auth|rocketchat-admin|rocketchat-tls)"
    
    # Check monitoring namespace secrets
    print_status "Monitoring namespace secrets:"
    kubectl get secrets -n "monitoring" | grep -E "(grafana-admin|alertmanager-smtp|alertmanager-webhook|grafana-tls)"
    
    print_success "Secrets verification completed"
}

# Main execution
main() {
    print_status "Starting Azure Key Vault secrets sync..."
    
    check_prerequisites
    create_namespace
    sync_mongodb_secrets
    sync_rocketchat_secrets
    sync_monitoring_secrets
    sync_ssl_secrets
    verify_secrets
    
    print_success "Azure Key Vault secrets sync completed successfully!"
    echo ""
    echo "🔐 Synced secrets:"
    echo "   • MongoDB authentication"
    echo "   • Rocket.Chat admin credentials"
    echo "   • Grafana admin credentials"
    echo "   • SMTP credentials for alerting"
    echo "   • SSL certificates"
    echo "   • Webhook URLs"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Deploy Rocket.Chat: kubectl apply -k k8s/overlays/production"
    echo "   2. Deploy monitoring (optional): kubectl apply -k k8s/overlays/monitoring"
    echo "   3. Verify deployment: kubectl get pods -n rocketchat"
}

# Run main function
main "$@"
