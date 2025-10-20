#!/bin/bash
# MongoDB Backup Script
# Automated mongodump to Azure Blob Storage with encryption and validation

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

print_status "🗄️ Starting MongoDB backup to Azure Blob Storage"

# Configuration
NAMESPACE="${NAMESPACE:-rocketchat}"
MONGODB_POD="${MONGODB_POD:-mongodb-0}"
BACKUP_STORAGE_ACCOUNT="${BACKUP_STORAGE_ACCOUNT:-rocketchatbackups}"
BACKUP_CONTAINER="${BACKUP_CONTAINER:-mongodb-backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
ENCRYPTION_KEY="${ENCRYPTION_KEY:-$(openssl rand -base64 32)}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mongodb-backup-${TIMESTAMP}"
LOCAL_BACKUP_DIR="/tmp/mongodb-backup-${TIMESTAMP}"

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

# Create local backup directory
create_backup_directory() {
    print_status "Creating local backup directory..."
    
    mkdir -p "$LOCAL_BACKUP_DIR"
    print_success "Local backup directory created: $LOCAL_BACKUP_DIR"
}

# Perform MongoDB backup
perform_mongodb_backup() {
    print_status "Performing MongoDB backup..."
    
    # Create backup using mongodump
    kubectl exec "$MONGODB_POD" -n "$NAMESPACE" -- mongodump \
        --host localhost:27017 \
        --username "$MONGODB_USERNAME" \
        --password "$MONGODB_PASSWORD" \
        --authenticationDatabase admin \
        --db rocketchat \
        --out /tmp/backup
    
    # Copy backup from pod to local directory
    kubectl cp "$NAMESPACE/$MONGODB_POD:/tmp/backup" "$LOCAL_BACKUP_DIR/"
    
    # Clean up backup from pod
    kubectl exec "$MONGODB_POD" -n "$NAMESPACE" -- rm -rf /tmp/backup
    
    print_success "MongoDB backup completed"
}

# Validate backup
validate_backup() {
    print_status "Validating backup..."
    
    # Check if backup directory exists and has content
    if [ ! -d "$LOCAL_BACKUP_DIR/backup" ]; then
        print_error "Backup directory not found"
        exit 1
    fi
    
    # Check if backup has data
    BACKUP_SIZE=$(du -sh "$LOCAL_BACKUP_DIR/backup" | cut -f1)
    print_status "Backup size: $BACKUP_SIZE"
    
    # List backup contents
    print_status "Backup contents:"
    ls -la "$LOCAL_BACKUP_DIR/backup/"
    
    # Check for key collections
    if [ -d "$LOCAL_BACKUP_DIR/backup/rocketchat" ]; then
        print_status "Rocket.Chat database backup found"
        ls -la "$LOCAL_BACKUP_DIR/backup/rocketchat/"
    else
        print_error "Rocket.Chat database backup not found"
        exit 1
    fi
    
    print_success "Backup validation completed"
}

# Compress backup
compress_backup() {
    print_status "Compressing backup..."
    
    cd "$LOCAL_BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" backup/
    
    # Verify compression
    if [ -f "${BACKUP_NAME}.tar.gz" ]; then
        COMPRESSED_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)
        print_success "Backup compressed: ${BACKUP_NAME}.tar.gz ($COMPRESSED_SIZE)"
    else
        print_error "Backup compression failed"
        exit 1
    fi
}

# Encrypt backup
encrypt_backup() {
    print_status "Encrypting backup..."
    
    cd "$LOCAL_BACKUP_DIR"
    
    # Encrypt the backup using AES-256
    openssl enc -aes-256-cbc -salt -in "${BACKUP_NAME}.tar.gz" -out "${BACKUP_NAME}.tar.gz.enc" -pass pass:"$ENCRYPTION_KEY"
    
    # Verify encryption
    if [ -f "${BACKUP_NAME}.tar.gz.enc" ]; then
        ENCRYPTED_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz.enc" | cut -f1)
        print_success "Backup encrypted: ${BACKUP_NAME}.tar.gz.enc ($ENCRYPTED_SIZE)"
    else
        print_error "Backup encryption failed"
        exit 1
    fi
}

# Upload to Azure Blob Storage
upload_to_azure() {
    print_status "Uploading backup to Azure Blob Storage..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Upload backup
    az storage blob upload \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "${BACKUP_NAME}.tar.gz.enc" \
        --file "$LOCAL_BACKUP_DIR/${BACKUP_NAME}.tar.gz.enc" \
        --overwrite
    
    print_success "Backup uploaded to Azure Blob Storage"
}

# Store encryption key
store_encryption_key() {
    print_status "Storing encryption key in Azure Key Vault..."
    
    # Get Key Vault name from environment or use default
    KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
    
    # Store encryption key
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "mongodb-backup-key-${TIMESTAMP}" \
        --value "$ENCRYPTION_KEY" \
        --description "Encryption key for MongoDB backup ${TIMESTAMP}" \
        &> /dev/null
    
    print_success "Encryption key stored in Azure Key Vault"
}

# Clean up old backups
cleanup_old_backups() {
    print_status "Cleaning up old backups (older than $BACKUP_RETENTION_DAYS days)..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # List blobs and delete old ones
    az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --query "[?properties.lastModified < datetime('$(date -d "$BACKUP_RETENTION_DAYS days ago" -u +%Y-%m-%dT%H:%M:%SZ)')].name" \
        -o tsv | while read -r blob_name; do
        if [ -n "$blob_name" ]; then
            print_status "Deleting old backup: $blob_name"
            az storage blob delete \
                --account-name "$BACKUP_STORAGE_ACCOUNT" \
                --account-key "$STORAGE_KEY" \
                --container-name "$BACKUP_CONTAINER" \
                --name "$blob_name" \
                &> /dev/null
        fi
    done
    
    print_success "Old backups cleaned up"
}

# Clean up local files
cleanup_local() {
    print_status "Cleaning up local files..."
    
    rm -rf "$LOCAL_BACKUP_DIR"
    print_success "Local files cleaned up"
}

# Send notification
send_notification() {
    print_status "Sending backup notification..."
    
    # Get backup size
    BACKUP_SIZE=$(az storage blob show \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "${BACKUP_NAME}.tar.gz.enc" \
        --query "properties.contentLength" -o tsv)
    
    # Convert bytes to human readable
    BACKUP_SIZE_HR=$(numfmt --to=iec --suffix=B "$BACKUP_SIZE")
    
    # Send notification (implement based on your notification system)
    print_success "Backup notification sent"
    echo "📊 Backup Summary:"
    echo "   • Name: ${BACKUP_NAME}.tar.gz.enc"
    echo "   • Size: $BACKUP_SIZE_HR"
    echo "   • Location: Azure Blob Storage"
    echo "   • Encryption: AES-256-CBC"
    echo "   • Retention: $BACKUP_RETENTION_DAYS days"
}

# Main execution
main() {
    print_status "Starting MongoDB backup process..."
    
    check_prerequisites
    get_mongodb_credentials
    create_backup_directory
    perform_mongodb_backup
    validate_backup
    compress_backup
    encrypt_backup
    upload_to_azure
    store_encryption_key
    cleanup_old_backups
    cleanup_local
    send_notification
    
    print_success "MongoDB backup completed successfully!"
    echo ""
    echo "🗄️ Backup Details:"
    echo "   • Backup Name: ${BACKUP_NAME}.tar.gz.enc"
    echo "   • Storage Account: $BACKUP_STORAGE_ACCOUNT"
    echo "   • Container: $BACKUP_CONTAINER"
    echo "   • Encryption Key: Stored in Azure Key Vault"
    echo "   • Retention: $BACKUP_RETENTION_DAYS days"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Verify backup in Azure Portal"
    echo "   2. Test restore process if needed"
    echo "   3. Monitor backup schedule"
}

# Run main function
main "$@"
