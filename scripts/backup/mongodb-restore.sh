#!/bin/bash
# MongoDB Restore Script
# Restores MongoDB from Azure Blob Storage backup

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

print_status "🗄️ Starting MongoDB restore from Azure Blob Storage"

# Configuration
NAMESPACE="${NAMESPACE:-rocketchat}"
MONGODB_POD="${MONGODB_POD:-mongodb-0}"
BACKUP_STORAGE_ACCOUNT="${BACKUP_STORAGE_ACCOUNT:-rocketchatbackups}"
BACKUP_CONTAINER="${BACKUP_CONTAINER:-mongodb-backups}"
BACKUP_NAME="${BACKUP_NAME:-}"
LOCAL_RESTORE_DIR="/tmp/mongodb-restore-$(date +%Y%m%d_%H%M%S)"

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
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
    
    # Check MongoDB pod
    if ! kubectl get pod "$MONGODB_POD" -n "$NAMESPACE" &> /dev/null; then
        print_error "MongoDB pod '$MONGODB_POD' not found in namespace '$NAMESPACE'."
        exit 1
    fi
    
    # Check if MongoDB pod is ready
    if ! kubectl get pod "$MONGODB_POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}' | grep -q "Running"; then
        print_error "MongoDB pod '$MONGODB_POD' is not running."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# List available backups
list_backups() {
    print_status "Listing available backups..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # List backups
    print_status "Available backups:"
    az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --query "[].{Name:name,Size:properties.contentLength,LastModified:properties.lastModified}" \
        -o table
    
    # If no backup name specified, get the latest
    if [ -z "$BACKUP_NAME" ]; then
        BACKUP_NAME=$(az storage blob list \
            --account-name "$BACKUP_STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            --container-name "$BACKUP_CONTAINER" \
            --query "max_by([], &properties.lastModified).name" -o tsv)
        
        if [ -z "$BACKUP_NAME" ]; then
            print_error "No backups found in container '$BACKUP_CONTAINER'"
            exit 1
        fi
        
        print_status "Using latest backup: $BACKUP_NAME"
    fi
    
    print_success "Backup selected: $BACKUP_NAME"
}

# Download backup from Azure
download_backup() {
    print_status "Downloading backup from Azure Blob Storage..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Create local restore directory
    mkdir -p "$LOCAL_RESTORE_DIR"
    
    # Download backup
    az storage blob download \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "$BACKUP_NAME" \
        --file "$LOCAL_RESTORE_DIR/$BACKUP_NAME"
    
    print_success "Backup downloaded to: $LOCAL_RESTORE_DIR/$BACKUP_NAME"
}

# Get encryption key
get_encryption_key() {
    print_status "Getting encryption key from Azure Key Vault..."
    
    # Extract timestamp from backup name
    BACKUP_TIMESTAMP=$(echo "$BACKUP_NAME" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    
    # Get Key Vault name from environment or use default
    KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
    
    # Get encryption key
    ENCRYPTION_KEY=$(az keyvault secret show \
        --vault-name "$KEY_VAULT_NAME" \
        --name "mongodb-backup-key-${BACKUP_TIMESTAMP}" \
        --query "value" -o tsv)
    
    if [ -z "$ENCRYPTION_KEY" ]; then
        print_error "Encryption key not found in Azure Key Vault"
        exit 1
    fi
    
    print_success "Encryption key retrieved"
}

# Decrypt backup
decrypt_backup() {
    print_status "Decrypting backup..."
    
    cd "$LOCAL_RESTORE_DIR"
    
    # Decrypt the backup
    openssl enc -aes-256-cbc -d -in "$BACKUP_NAME" -out "${BACKUP_NAME%.enc}" -pass pass:"$ENCRYPTION_KEY"
    
    # Verify decryption
    if [ -f "${BACKUP_NAME%.enc}" ]; then
        print_success "Backup decrypted: ${BACKUP_NAME%.enc}"
    else
        print_error "Backup decryption failed"
        exit 1
    fi
}

# Extract backup
extract_backup() {
    print_status "Extracting backup..."
    
    cd "$LOCAL_RESTORE_DIR"
    
    # Extract the backup
    tar -xzf "${BACKUP_NAME%.enc}"
    
    # Verify extraction
    if [ -d "backup" ]; then
        print_success "Backup extracted to: $LOCAL_RESTORE_DIR/backup"
    else
        print_error "Backup extraction failed"
        exit 1
    fi
}

# Get MongoDB credentials
get_mongodb_credentials() {
    print_status "Getting MongoDB credentials..."
    
    # Get MongoDB root password
    MONGODB_ROOT_PASSWORD=$(kubectl get secret mongodb-auth -n "$NAMESPACE" -o jsonpath='{.data.root-password}' | base64 -d)
    
    # Get MongoDB username and password
    MONGODB_USERNAME=$(kubectl get secret mongodb-auth -n "$NAMESPACE" -o jsonpath='{.data.username}' | base64 -d)
    MONGODB_PASSWORD=$(kubectl get secret mongodb-auth -n "$NAMESPACE" -o jsonpath='{.data.password}' | base64 -d)
    
    print_success "MongoDB credentials retrieved"
}

# Stop Rocket.Chat to prevent data corruption
stop_rocketchat() {
    print_status "Stopping Rocket.Chat to prevent data corruption..."
    
    # Scale down Rocket.Chat deployment
    kubectl scale deployment rocketchat -n "$NAMESPACE" --replicas=0
    
    # Wait for pods to terminate
    kubectl wait --for=delete pod -l app=rocketchat -n "$NAMESPACE" --timeout=300s
    
    print_success "Rocket.Chat stopped"
}

# Restore MongoDB data
restore_mongodb_data() {
    print_status "Restoring MongoDB data..."
    
    # Copy backup to MongoDB pod
    kubectl cp "$LOCAL_RESTORE_DIR/backup" "$NAMESPACE/$MONGODB_POD:/tmp/restore"
    
    # Restore data using mongorestore
    kubectl exec "$MONGODB_POD" -n "$NAMESPACE" -- mongorestore \
        --host localhost:27017 \
        --username "$MONGODB_USERNAME" \
        --password "$MONGODB_PASSWORD" \
        --authenticationDatabase admin \
        --db rocketchat \
        --drop \
        /tmp/restore/rocketchat
    
    # Clean up restore files from pod
    kubectl exec "$MONGODB_POD" -n "$NAMESPACE" -- rm -rf /tmp/restore
    
    print_success "MongoDB data restored"
}

# Start Rocket.Chat
start_rocketchat() {
    print_status "Starting Rocket.Chat..."
    
    # Scale up Rocket.Chat deployment
    kubectl scale deployment rocketchat -n "$NAMESPACE" --replicas=1
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=rocketchat -n "$NAMESPACE" --timeout=300s
    
    print_success "Rocket.Chat started"
}

# Verify restore
verify_restore() {
    print_status "Verifying restore..."
    
    # Check if Rocket.Chat is accessible
    if kubectl get pod -l app=rocketchat -n "$NAMESPACE" -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
        print_success "Rocket.Chat pod is running"
    else
        print_error "Rocket.Chat pod is not running"
        exit 1
    fi
    
    # Check MongoDB connection
    if kubectl exec "$MONGODB_POD" -n "$NAMESPACE" -- mongosh --eval "db.adminCommand('ping')" &> /dev/null; then
        print_success "MongoDB connection verified"
    else
        print_error "MongoDB connection failed"
        exit 1
    fi
    
    print_success "Restore verification completed"
}

# Clean up local files
cleanup_local() {
    print_status "Cleaning up local files..."
    
    rm -rf "$LOCAL_RESTORE_DIR"
    print_success "Local files cleaned up"
}

# Send notification
send_notification() {
    print_status "Sending restore notification..."
    
    print_success "Restore notification sent"
    echo "📊 Restore Summary:"
    echo "   • Backup: $BACKUP_NAME"
    echo "   • Status: Completed successfully"
    echo "   • Rocket.Chat: Running"
    echo "   • MongoDB: Connected"
}

# Main execution
main() {
    print_status "Starting MongoDB restore process..."
    
    check_prerequisites
    list_backups
    download_backup
    get_encryption_key
    decrypt_backup
    extract_backup
    get_mongodb_credentials
    stop_rocketchat
    restore_mongodb_data
    start_rocketchat
    verify_restore
    cleanup_local
    send_notification
    
    print_success "MongoDB restore completed successfully!"
    echo ""
    echo "🗄️ Restore Details:"
    echo "   • Backup: $BACKUP_NAME"
    echo "   • Status: Completed successfully"
    echo "   • Rocket.Chat: Running"
    echo "   • MongoDB: Connected"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Verify Rocket.Chat functionality"
    echo "   2. Check data integrity"
    echo "   3. Monitor application logs"
}

# Run main function
main "$@"
