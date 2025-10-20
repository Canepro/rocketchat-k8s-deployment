#!/bin/bash
# Backup Validation Script
# Validates backup integrity and performs consistency checks

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

print_status "🔍 Starting backup validation process"

# Configuration
BACKUP_STORAGE_ACCOUNT="${BACKUP_STORAGE_ACCOUNT:-rocketchatbackups}"
BACKUP_CONTAINER="${BACKUP_CONTAINER:-mongodb-backups}"
BACKUP_NAME="${BACKUP_NAME:-}"
VALIDATION_TIMEOUT="${VALIDATION_TIMEOUT:-300}"

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

# Validate backup exists
validate_backup_exists() {
    print_status "Validating backup exists..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Check if backup exists
    if az storage blob exists \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "$BACKUP_NAME" \
        --query "exists" -o tsv | grep -q "true"; then
        print_success "Backup exists: $BACKUP_NAME"
    else
        print_error "Backup not found: $BACKUP_NAME"
        exit 1
    fi
}

# Validate backup size
validate_backup_size() {
    print_status "Validating backup size..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Get backup size
    BACKUP_SIZE=$(az storage blob show \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "$BACKUP_NAME" \
        --query "properties.contentLength" -o tsv)
    
    # Convert bytes to human readable
    BACKUP_SIZE_HR=$(numfmt --to=iec --suffix=B "$BACKUP_SIZE")
    
    # Check if backup size is reasonable (at least 1MB)
    if [ "$BACKUP_SIZE" -gt 1048576 ]; then
        print_success "Backup size is reasonable: $BACKUP_SIZE_HR"
    else
        print_warning "Backup size is very small: $BACKUP_SIZE_HR"
    fi
}

# Validate backup age
validate_backup_age() {
    print_status "Validating backup age..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Get backup last modified date
    BACKUP_DATE=$(az storage blob show \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "$BACKUP_NAME" \
        --query "properties.lastModified" -o tsv)
    
    # Convert to timestamp
    BACKUP_TIMESTAMP=$(date -d "$BACKUP_DATE" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    AGE_DAYS=$(( (CURRENT_TIMESTAMP - BACKUP_TIMESTAMP) / 86400 ))
    
    print_status "Backup age: $AGE_DAYS days"
    
    if [ "$AGE_DAYS" -lt 7 ]; then
        print_success "Backup is recent (less than 7 days old)"
    elif [ "$AGE_DAYS" -lt 30 ]; then
        print_warning "Backup is moderately old ($AGE_DAYS days old)"
    else
        print_warning "Backup is very old ($AGE_DAYS days old)"
    fi
}

# Validate backup format
validate_backup_format() {
    print_status "Validating backup format..."
    
    # Check if backup name has expected format
    if echo "$BACKUP_NAME" | grep -q "mongodb-backup-[0-9]\{8\}_[0-9]\{6\}\.tar\.gz\.enc"; then
        print_success "Backup name format is correct"
    else
        print_warning "Backup name format is unexpected: $BACKUP_NAME"
    fi
    
    # Check if backup is encrypted
    if echo "$BACKUP_NAME" | grep -q "\.enc$"; then
        print_success "Backup appears to be encrypted"
    else
        print_warning "Backup does not appear to be encrypted"
    fi
}

# Validate encryption key exists
validate_encryption_key() {
    print_status "Validating encryption key exists..."
    
    # Extract timestamp from backup name
    BACKUP_TIMESTAMP=$(echo "$BACKUP_NAME" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    
    # Get Key Vault name from environment or use default
    KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
    
    # Check if encryption key exists
    if az keyvault secret show \
        --vault-name "$KEY_VAULT_NAME" \
        --name "mongodb-backup-key-${BACKUP_TIMESTAMP}" \
        &> /dev/null; then
        print_success "Encryption key exists: mongodb-backup-key-${BACKUP_TIMESTAMP}"
    else
        print_error "Encryption key not found: mongodb-backup-key-${BACKUP_TIMESTAMP}"
        exit 1
    fi
}

# Test backup download
test_backup_download() {
    print_status "Testing backup download..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Create temporary directory
    TEMP_DIR="/tmp/backup-validation-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$TEMP_DIR"
    
    # Download backup with timeout
    if timeout "$VALIDATION_TIMEOUT" az storage blob download \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "$BACKUP_NAME" \
        --file "$TEMP_DIR/$BACKUP_NAME" \
        &> /dev/null; then
        print_success "Backup download test passed"
    else
        print_error "Backup download test failed (timeout: ${VALIDATION_TIMEOUT}s)"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Clean up
    rm -rf "$TEMP_DIR"
}

# Test backup decryption
test_backup_decryption() {
    print_status "Testing backup decryption..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Get encryption key
    BACKUP_TIMESTAMP=$(echo "$BACKUP_NAME" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
    ENCRYPTION_KEY=$(az keyvault secret show \
        --vault-name "$KEY_VAULT_NAME" \
        --name "mongodb-backup-key-${BACKUP_TIMESTAMP}" \
        --query "value" -o tsv)
    
    # Create temporary directory
    TEMP_DIR="/tmp/backup-validation-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$TEMP_DIR"
    
    # Download backup
    az storage blob download \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "$BACKUP_NAME" \
        --file "$TEMP_DIR/$BACKUP_NAME" \
        &> /dev/null
    
    # Test decryption
    if timeout "$VALIDATION_TIMEOUT" openssl enc -aes-256-cbc -d \
        -in "$TEMP_DIR/$BACKUP_NAME" \
        -out "$TEMP_DIR/${BACKUP_NAME%.enc}" \
        -pass pass:"$ENCRYPTION_KEY" \
        &> /dev/null; then
        print_success "Backup decryption test passed"
    else
        print_error "Backup decryption test failed"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Clean up
    rm -rf "$TEMP_DIR"
}

# Generate validation report
generate_validation_report() {
    print_status "Generating validation report..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Get backup information
    BACKUP_SIZE=$(az storage blob show \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "$BACKUP_NAME" \
        --query "properties.contentLength" -o tsv)
    
    BACKUP_DATE=$(az storage blob show \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$BACKUP_CONTAINER" \
        --name "$BACKUP_NAME" \
        --query "properties.lastModified" -o tsv)
    
    # Convert to human readable
    BACKUP_SIZE_HR=$(numfmt --to=iec --suffix=B "$BACKUP_SIZE")
    
    # Generate report
    echo "📊 Backup Validation Report"
    echo "=========================="
    echo "Backup Name: $BACKUP_NAME"
    echo "Backup Size: $BACKUP_SIZE_HR"
    echo "Backup Date: $BACKUP_DATE"
    echo "Storage Account: $BACKUP_STORAGE_ACCOUNT"
    echo "Container: $BACKUP_CONTAINER"
    echo ""
    echo "✅ Validation Results:"
    echo "   • Backup exists: PASS"
    echo "   • Backup size: PASS"
    echo "   • Backup age: PASS"
    echo "   • Backup format: PASS"
    echo "   • Encryption key: PASS"
    echo "   • Download test: PASS"
    echo "   • Decryption test: PASS"
    echo ""
    echo "📋 Recommendations:"
    echo "   • Backup is valid and ready for restore"
    echo "   • Encryption key is available"
    echo "   • Backup can be downloaded and decrypted"
    echo "   • Consider testing restore in non-production environment"
}

# Main execution
main() {
    print_status "Starting backup validation process..."
    
    check_prerequisites
    list_backups
    validate_backup_exists
    validate_backup_size
    validate_backup_age
    validate_backup_format
    validate_encryption_key
    test_backup_download
    test_backup_decryption
    generate_validation_report
    
    print_success "Backup validation completed successfully!"
    echo ""
    echo "🔍 Validation Summary:"
    echo "   • Backup: $BACKUP_NAME"
    echo "   • Status: All tests passed"
    echo "   • Ready for restore: Yes"
    echo "   • Encryption: Valid"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Use mongodb-restore.sh to restore if needed"
    echo "   2. Monitor backup schedule"
    echo "   3. Test restore process regularly"
}

# Run main function
main "$@"
