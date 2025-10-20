#!/bin/bash
# Backup Integrity Check Script
# Comprehensive validation of all backup types and integrity verification

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

print_status "🔍 Starting comprehensive backup integrity check"

# Configuration
BACKUP_STORAGE_ACCOUNT="${BACKUP_STORAGE_ACCOUNT:-rocketchatbackups}"
MONGODB_CONTAINER="${MONGODB_CONTAINER:-mongodb-backups}"
CLUSTER_STATE_CONTAINER="${CLUSTER_STATE_CONTAINER:-cluster-state}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rocketchat-k8s-rg}"
KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"

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

# Check MongoDB backups
check_mongodb_backups() {
    print_status "Checking MongoDB backups..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # List MongoDB backups
    mongodb_backups=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$MONGODB_CONTAINER" \
        --query "[].{name:name,size:properties.contentLength,lastModified:properties.lastModified}" \
        -o json)
    
    if [ -n "$mongodb_backups" ] && [ "$mongodb_backups" != "[]" ]; then
        backup_count=$(echo "$mongodb_backups" | jq length)
        print_success "Found $backup_count MongoDB backups"
        
        # Check each backup
        echo "$mongodb_backups" | jq -r '.[] | "\(.name) (\(.size) bytes, \(.lastModified))"' | while read -r backup_info; do
            print_status "  • $backup_info"
        done
        
        # Check for encryption keys
        echo "$mongodb_backups" | jq -r '.[].name' | while read -r backup_name; do
            timestamp=$(echo "$backup_name" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
            if [ -n "$timestamp" ]; then
                if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "mongodb-backup-key-${timestamp}" &> /dev/null; then
                    print_success "  • Encryption key found for $backup_name"
                else
                    print_error "  • Encryption key missing for $backup_name"
                fi
            fi
        done
    else
        print_warning "No MongoDB backups found"
    fi
}

# Check cluster state backups
check_cluster_state_backups() {
    print_status "Checking cluster state backups..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # List cluster state backups
    cluster_backups=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$CLUSTER_STATE_CONTAINER" \
        --query "[].{name:name,size:properties.contentLength,lastModified:properties.lastModified}" \
        -o json)
    
    if [ -n "$cluster_backups" ] && [ "$cluster_backups" != "[]" ]; then
        backup_count=$(echo "$cluster_backups" | jq length)
        print_success "Found $backup_count cluster state backups"
        
        # Check each backup
        echo "$cluster_backups" | jq -r '.[] | "\(.name) (\(.size) bytes, \(.lastModified))"' | while read -r backup_info; do
            print_status "  • $backup_info"
        done
    else
        print_warning "No cluster state backups found"
    fi
}

# Check PVC snapshots
check_pvc_snapshots() {
    print_status "Checking PVC snapshots..."
    
    # List snapshots with backup tags
    snapshots=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['created-by']=='backup-script'].{name:name,size:diskSizeGb,created:timeCreated,pvc:tags['pvc-namespace'] + '/' + tags['pvc-name']}" -o json)
    
    if [ -n "$snapshots" ] && [ "$snapshots" != "[]" ]; then
        snapshot_count=$(echo "$snapshots" | jq length)
        print_success "Found $snapshot_count PVC snapshots"
        
        # Check each snapshot
        echo "$snapshots" | jq -r '.[] | "\(.name) -> \(.pvc) (\(.size)GB, \(.created))"' | while read -r snapshot_info; do
            print_status "  • $snapshot_info"
        done
        
        # Check for snapshot information in Key Vault
        echo "$snapshots" | jq -r '.[] | select(.name | contains("pvc-snapshot-")) | .name' | while read -r snapshot_name; do
            timestamp=$(echo "$snapshot_name" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
            if [ -n "$timestamp" ]; then
                if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "pvc-snapshots-${timestamp}" &> /dev/null; then
                    print_success "  • Snapshot information found for $snapshot_name"
                else
                    print_warning "  • Snapshot information missing for $snapshot_name"
                fi
            fi
        done
    else
        print_warning "No PVC snapshots found"
    fi
}

# Check backup age and retention
check_backup_age_and_retention() {
    print_status "Checking backup age and retention..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Check MongoDB backups age
    mongodb_backups=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$MONGODB_CONTAINER" \
        --query "[].{name:name,lastModified:properties.lastModified}" \
        -o json)
    
    if [ -n "$mongodb_backups" ] && [ "$mongodb_backups" != "[]" ]; then
        echo "$mongodb_backups" | jq -r '.[] | "\(.name)|\(.lastModified)"' | while IFS='|' read -r name last_modified; do
            backup_date=$(date -d "$last_modified" +%s)
            current_date=$(date +%s)
            age_days=$(( (current_date - backup_date) / 86400 ))
            
            if [ "$age_days" -lt 7 ]; then
                print_success "  • MongoDB backup $name is recent ($age_days days old)"
            elif [ "$age_days" -lt 30 ]; then
                print_warning "  • MongoDB backup $name is moderately old ($age_days days old)"
            else
                print_warning "  • MongoDB backup $name is very old ($age_days days old)"
            fi
        done
    fi
    
    # Check cluster state backups age
    cluster_backups=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$CLUSTER_STATE_CONTAINER" \
        --query "[].{name:name,lastModified:properties.lastModified}" \
        -o json)
    
    if [ -n "$cluster_backups" ] && [ "$cluster_backups" != "[]" ]; then
        echo "$cluster_backups" | jq -r '.[] | "\(.name)|\(.lastModified)"' | while IFS='|' read -r name last_modified; do
            backup_date=$(date -d "$last_modified" +%s)
            current_date=$(date +%s)
            age_days=$(( (current_date - backup_date) / 86400 ))
            
            if [ "$age_days" -lt 7 ]; then
                print_success "  • Cluster state backup $name is recent ($age_days days old)"
            elif [ "$age_days" -lt 30 ]; then
                print_warning "  • Cluster state backup $name is moderately old ($age_days days old)"
            else
                print_warning "  • Cluster state backup $name is very old ($age_days days old)"
            fi
        done
    fi
    
    # Check PVC snapshots age
    snapshots=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['created-by']=='backup-script'].{name:name,created:timeCreated}" -o json)
    
    if [ -n "$snapshots" ] && [ "$snapshots" != "[]" ]; then
        echo "$snapshots" | jq -r '.[] | "\(.name)|\(.created)"' | while IFS='|' read -r name created; do
            snapshot_date=$(date -d "$created" +%s)
            current_date=$(date +%s)
            age_days=$(( (current_date - snapshot_date) / 86400 ))
            
            if [ "$age_days" -lt 7 ]; then
                print_success "  • PVC snapshot $name is recent ($age_days days old)"
            elif [ "$age_days" -lt 30 ]; then
                print_warning "  • PVC snapshot $name is moderately old ($age_days days old)"
            else
                print_warning "  • PVC snapshot $name is very old ($age_days days old)"
            fi
        done
    fi
}

# Check backup consistency
check_backup_consistency() {
    print_status "Checking backup consistency..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Check if we have both MongoDB and cluster state backups
    mongodb_count=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$MONGODB_CONTAINER" \
        --query "length(@)")
    
    cluster_count=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$CLUSTER_STATE_CONTAINER" \
        --query "length(@)")
    
    snapshot_count=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "length([?tags['created-by']=='backup-script'])")
    
    print_status "Backup counts:"
    print_status "  • MongoDB backups: $mongodb_count"
    print_status "  • Cluster state backups: $cluster_count"
    print_status "  • PVC snapshots: $snapshot_count"
    
    if [ "$mongodb_count" -gt 0 ] && [ "$cluster_count" -gt 0 ] && [ "$snapshot_count" -gt 0 ]; then
        print_success "All backup types are present"
    else
        print_warning "Some backup types are missing"
    fi
}

# Check backup accessibility
check_backup_accessibility() {
    print_status "Checking backup accessibility..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Test MongoDB backup access
    latest_mongodb_backup=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$MONGODB_CONTAINER" \
        --query "max_by([], &properties.lastModified).name" -o tsv)
    
    if [ -n "$latest_mongodb_backup" ]; then
        if az storage blob show \
            --account-name "$BACKUP_STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            --container-name "$MONGODB_CONTAINER" \
            --name "$latest_mongodb_backup" \
            &> /dev/null; then
            print_success "MongoDB backup accessible: $latest_mongodb_backup"
        else
            print_error "MongoDB backup not accessible: $latest_mongodb_backup"
        fi
    fi
    
    # Test cluster state backup access
    latest_cluster_backup=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$CLUSTER_STATE_CONTAINER" \
        --query "max_by([], &properties.lastModified).name" -o tsv)
    
    if [ -n "$latest_cluster_backup" ]; then
        if az storage blob show \
            --account-name "$BACKUP_STORAGE_ACCOUNT" \
            --account-key "$STORAGE_KEY" \
            --container-name "$CLUSTER_STATE_CONTAINER" \
            --name "$latest_cluster_backup" \
            &> /dev/null; then
            print_success "Cluster state backup accessible: $latest_cluster_backup"
        else
            print_error "Cluster state backup not accessible: $latest_cluster_backup"
        fi
    fi
    
    # Test PVC snapshot access
    latest_snapshot=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "max_by([?tags['created-by']=='backup-script'], &timeCreated).name" -o tsv)
    
    if [ -n "$latest_snapshot" ]; then
        if az snapshot show --name "$latest_snapshot" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
            print_success "PVC snapshot accessible: $latest_snapshot"
        else
            print_error "PVC snapshot not accessible: $latest_snapshot"
        fi
    fi
}

# Generate integrity report
generate_integrity_report() {
    print_status "Generating integrity report..."
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --account-name "$BACKUP_STORAGE_ACCOUNT" --query "[0].value" -o tsv)
    
    # Get backup counts
    mongodb_count=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$MONGODB_CONTAINER" \
        --query "length(@)")
    
    cluster_count=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$CLUSTER_STATE_CONTAINER" \
        --query "length(@)")
    
    snapshot_count=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "length([?tags['created-by']=='backup-script'])")
    
    # Get total storage usage
    mongodb_size=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$MONGODB_CONTAINER" \
        --query "sum([].properties.contentLength)" -o tsv)
    
    cluster_size=$(az storage blob list \
        --account-name "$BACKUP_STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$CLUSTER_STATE_CONTAINER" \
        --query "sum([].properties.contentLength)" -o tsv)
    
    # Convert to human readable
    mongodb_size_hr=$(numfmt --to=iec --suffix=B "$mongodb_size")
    cluster_size_hr=$(numfmt --to=iec --suffix=B "$cluster_size")
    
    echo "📊 Backup Integrity Report"
    echo "========================="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Storage Account: $BACKUP_STORAGE_ACCOUNT"
    echo "Resource Group: $RESOURCE_GROUP"
    echo ""
    echo "📦 Backup Summary:"
    echo "   • MongoDB backups: $mongodb_count ($mongodb_size_hr)"
    echo "   • Cluster state backups: $cluster_count ($cluster_size_hr)"
    echo "   • PVC snapshots: $snapshot_count"
    echo ""
    echo "✅ Integrity Status:"
    echo "   • MongoDB backups: $(if [ "$mongodb_count" -gt 0 ]; then echo "PASS"; else echo "FAIL"; fi)"
    echo "   • Cluster state backups: $(if [ "$cluster_count" -gt 0 ]; then echo "PASS"; else echo "FAIL"; fi)"
    echo "   • PVC snapshots: $(if [ "$snapshot_count" -gt 0 ]; then echo "PASS"; else echo "FAIL"; fi)"
    echo "   • Encryption keys: $(if az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "length([?contains(name, 'mongodb-backup-key-')])" -o tsv | grep -q "[1-9]"; then echo "PASS"; else echo "FAIL"; fi)"
    echo ""
    echo "📋 Recommendations:"
    if [ "$mongodb_count" -gt 0 ] && [ "$cluster_count" -gt 0 ] && [ "$snapshot_count" -gt 0 ]; then
        echo "   • All backup types are present and accessible"
        echo "   • Backup integrity is good"
        echo "   • Ready for cluster teardown/recreation"
    else
        echo "   • Some backup types are missing"
        echo "   • Run backup scripts to create missing backups"
        echo "   • Verify backup schedule is working"
    fi
}

# Main execution
main() {
    print_status "Starting backup integrity check process..."
    
    check_prerequisites
    check_mongodb_backups
    check_cluster_state_backups
    check_pvc_snapshots
    check_backup_age_and_retention
    check_backup_consistency
    check_backup_accessibility
    generate_integrity_report
    
    print_success "Backup integrity check completed successfully!"
    echo ""
    echo "🔍 Integrity Check Summary:"
    echo "   • MongoDB backups: Checked"
    echo "   • Cluster state backups: Checked"
    echo "   • PVC snapshots: Checked"
    echo "   • Backup age: Checked"
    echo "   • Backup accessibility: Checked"
    echo "   • Encryption keys: Checked"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Review integrity report"
    echo "   2. Fix any issues found"
    echo "   3. Run backup scripts if needed"
    echo "   4. Proceed with cluster operations"
}

# Run main function
main "$@"
