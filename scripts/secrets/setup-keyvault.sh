#!/bin/bash
# Azure Key Vault Setup Script
# Creates Key Vault and initializes with default secrets

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

print_status "🔐 Setting up Azure Key Vault for secrets management"

# Configuration
KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rocketchat-k8s-rg}"
LOCATION="${LOCATION:-UK South}"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
CURRENT_USER_ID=$(az account show --query user.name -o tsv)

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Please run 'az login'."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create resource group if it doesn't exist
create_resource_group() {
    print_status "Creating resource group '$RESOURCE_GROUP' if it doesn't exist..."
    
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        print_success "Resource group '$RESOURCE_GROUP' created"
    else
        print_success "Resource group '$RESOURCE_GROUP' already exists"
    fi
}

# Create Key Vault
create_key_vault() {
    print_status "Creating Azure Key Vault '$KEY_VAULT_NAME'..."
    
    if ! az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        az keyvault create \
            --name "$KEY_VAULT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --sku standard \
            --enable-soft-delete true \
            --soft-delete-retention-days 7 \
            --enable-purge-protection false
        
        print_success "Key Vault '$KEY_VAULT_NAME' created"
    else
        print_success "Key Vault '$KEY_VAULT_NAME' already exists"
    fi
}

# Set access policies
set_access_policies() {
    print_status "Setting Key Vault access policies..."
    
    # Get current user object ID
    CURRENT_USER_OBJECT_ID=$(az ad user show --id "$CURRENT_USER_ID" --query id -o tsv 2>/dev/null || az ad signed-in-user show --query id -o tsv)
    
    # Set access policy for current user
    az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --object-id "$CURRENT_USER_OBJECT_ID" \
        --secret-permissions get list set delete purge recover \
        --key-permissions get list create delete update import \
        --certificate-permissions get list create delete update import
    
    print_success "Access policies set for current user"
}

# Initialize with default secrets
initialize_default_secrets() {
    print_status "Initializing Key Vault with default secrets..."
    
    # MongoDB secrets
    print_status "Setting MongoDB secrets..."
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongodb-username" --value "rocketchat" &> /dev/null
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongodb-password" --value "SuperStrongPass!" &> /dev/null
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongodb-root-password" --value "MongoRoot2024!" &> /dev/null
    
    # Rocket.Chat secrets
    print_status "Setting Rocket.Chat secrets..."
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "rocketchat-admin-user" --value "admin" &> /dev/null
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "rocketchat-admin-password" --value "AdminPass2024!" &> /dev/null
    
    # MongoDB connection strings
    MONGO_URL="mongodb://rocketchat:SuperStrongPass!@mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017,mongodb-1.mongodb-headless.rocketchat.svc.cluster.local:27017,mongodb-2.mongodb-headless.rocketchat.svc.cluster.local:27017/rocketchat?replicaSet=rs0&readPreference=primaryPreferred"
    MONGO_OPLOG_URL="mongodb://rocketchat:SuperStrongPass!@mongodb-0.mongodb-headless.rocketchat.svc.cluster.local:27017/local?replicaSet=rs0&readPreference=primaryPreferred"
    
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongo-url" --value "$MONGO_URL" &> /dev/null
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "mongo-oplog-url" --value "$MONGO_OPLOG_URL" &> /dev/null
    
    # Grafana secrets
    print_status "Setting Grafana secrets..."
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "grafana-admin-user" --value "admin" &> /dev/null
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "grafana-admin-password" --value "GrafanaAdmin2024!" &> /dev/null
    
    # SMTP secrets (placeholder values)
    print_status "Setting SMTP secrets (placeholder values)..."
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "smtp-username" --value "your-email@gmail.com" &> /dev/null
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "smtp-password" --value "your-app-password" &> /dev/null
    
    # Webhook secrets (placeholder values)
    print_status "Setting webhook secrets (placeholder values)..."
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "rocketchat-webhook-url" --value "https://your-webhook-url" &> /dev/null
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "alert-email-recipient" --value "admin@yourdomain.com" &> /dev/null
    
    print_success "Default secrets initialized"
}

# Create SSL certificate secrets (placeholder)
create_ssl_secrets() {
    print_status "Creating SSL certificate secrets (placeholder)..."
    
    # Create self-signed certificate for testing
    openssl req -x509 -newkey rsa:4096 -keyout /tmp/ssl.key -out /tmp/ssl.crt -days 365 -nodes -subj "/CN=<YOUR_DOMAIN>" &> /dev/null
    
    # Store in Key Vault
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "ssl-certificate" --file /tmp/ssl.crt &> /dev/null
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "ssl-private-key" --file /tmp/ssl.key &> /dev/null
    
    # Clean up temporary files
    rm -f /tmp/ssl.key /tmp/ssl.crt
    
    print_success "SSL certificate secrets created (self-signed for testing)"
}

# Verify setup
verify_setup() {
    print_status "Verifying Key Vault setup..."
    
    # List secrets
    print_status "Secrets in Key Vault '$KEY_VAULT_NAME':"
    az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "[].name" -o table
    
    # Test secret retrieval
    print_status "Testing secret retrieval..."
    TEST_SECRET=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "mongodb-username" --query "value" -o tsv)
    if [ "$TEST_SECRET" = "rocketchat" ]; then
        print_success "Secret retrieval test passed"
    else
        print_error "Secret retrieval test failed"
        exit 1
    fi
    
    print_success "Key Vault setup verification completed"
}

# Main execution
main() {
    print_status "Starting Azure Key Vault setup..."
    
    check_prerequisites
    create_resource_group
    create_key_vault
    set_access_policies
    initialize_default_secrets
    create_ssl_secrets
    verify_setup
    
    print_success "Azure Key Vault setup completed successfully!"
    echo ""
    echo "🔐 Key Vault Information:"
    echo "   • Name: $KEY_VAULT_NAME"
    echo "   • Resource Group: $RESOURCE_GROUP"
    echo "   • Location: $LOCATION"
    echo "   • Subscription: $SUBSCRIPTION_ID"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Update placeholder secrets with real values:"
    echo "      • SMTP credentials for alerting"
    echo "      • Webhook URLs for notifications"
    echo "      • SSL certificates for production"
    echo "   2. Use sync-from-keyvault.sh to deploy secrets to cluster"
    echo "   3. Use backup-secrets-to-keyvault.sh to backup cluster secrets"
    echo ""
    echo "⚠️  Important: Update placeholder secrets before production use!"
}

# Run main function
main "$@"
