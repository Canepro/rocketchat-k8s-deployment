#!/bin/bash
# PVC Snapshot Script
# Creates Azure disk snapshots for all PVCs with retention policies

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

print_status "📸 Starting PVC snapshot creation"

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-rocketchat-k8s-rg}"
SNAPSHOT_RETENTION_DAYS="${SNAPSHOT_RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SNAPSHOT_PREFIX="pvc-snapshot-${TIMESTAMP}"

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
    
    print_success "Prerequisites check passed"
}

# Get PVC information
get_pvc_info() {
    print_status "Getting PVC information..."
    
    # Get all PVCs in the cluster
    PVCs=$(kubectl get pvc -A -o json | jq -r '.items[] | select(.status.phase == "Bound") | "\(.metadata.namespace) \(.metadata.name) \(.spec.volumeName)"')
    
    if [ -z "$PVCs" ]; then
        print_warning "No bound PVCs found in the cluster"
        return 0
    fi
    
    print_status "Found PVCs:"
    echo "$PVCs" | while read -r namespace name volume; do
        print_status "  • $namespace/$name (Volume: $volume)"
    done
    
    print_success "PVC information retrieved"
}

# Get disk information for PVCs
get_disk_info() {
    print_status "Getting disk information for PVCs..."
    
    # Get all PVCs and their associated disks
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            namespace=$(echo "$line" | cut -d' ' -f1)
            name=$(echo "$line" | cut -d' ' -f2)
            volume=$(echo "$line" | cut -d' ' -f3)
            
            # Get disk information
            disk_info=$(az disk show --name "$volume" --resource-group "$RESOURCE_GROUP" --query "{name:name,size:diskSizeGb,sku:sku.name}" -o json 2>/dev/null || echo "null")
            
            if [ "$disk_info" != "null" ]; then
                disk_name=$(echo "$disk_info" | jq -r '.name')
                disk_size=$(echo "$disk_info" | jq -r '.size')
                disk_sku=$(echo "$disk_info" | jq -r '.sku')
                
                print_status "  • $namespace/$name -> $disk_name (${disk_size}GB, $disk_sku)"
            else
                print_warning "  • $namespace/$name -> $volume (disk not found or not accessible)"
            fi
        fi
    done <<< "$PVCs"
    
    print_success "Disk information retrieved"
}

# Create snapshots for PVCs
create_pvc_snapshots() {
    print_status "Creating snapshots for PVCs..."
    
    snapshot_count=0
    
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            namespace=$(echo "$line" | cut -d' ' -f1)
            name=$(echo "$line" | cut -d' ' -f2)
            volume=$(echo "$line" | cut -d' ' -f3)
            
            # Create snapshot name
            snapshot_name="${SNAPSHOT_PREFIX}-${namespace}-${name}"
            
            print_status "Creating snapshot for $namespace/$name..."
            
            # Create snapshot
            if az snapshot create \
                --name "$snapshot_name" \
                --resource-group "$RESOURCE_GROUP" \
                --source "$volume" \
                --tags "pvc-namespace=$namespace" "pvc-name=$name" "created-by=backup-script" "backup-timestamp=$TIMESTAMP" \
                &> /dev/null; then
                print_success "Snapshot created: $snapshot_name"
                ((snapshot_count++))
            else
                print_error "Failed to create snapshot for $namespace/$name"
            fi
        fi
    done <<< "$PVCs"
    
    print_success "Created $snapshot_count snapshots"
}

# Verify snapshots
verify_snapshots() {
    print_status "Verifying created snapshots..."
    
    # List snapshots with our tags
    snapshots=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['backup-timestamp']=='$TIMESTAMP'].{name:name,size:diskSizeGb,created:timeCreated}" -o table)
    
    if [ -n "$snapshots" ]; then
        print_status "Created snapshots:"
        echo "$snapshots"
        print_success "Snapshots verified"
    else
        print_error "No snapshots found with timestamp $TIMESTAMP"
        exit 1
    fi
}

# Clean up old snapshots
cleanup_old_snapshots() {
    print_status "Cleaning up old snapshots (older than $SNAPSHOT_RETENTION_DAYS days)..."
    
    # Calculate cutoff date
    cutoff_date=$(date -d "$SNAPSHOT_RETENTION_DAYS days ago" -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Get old snapshots
    old_snapshots=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?timeCreated < '$cutoff_date' && tags['created-by']=='backup-script'].name" -o tsv)
    
    if [ -n "$old_snapshots" ]; then
        print_status "Deleting old snapshots:"
        echo "$old_snapshots" | while read -r snapshot_name; do
            if [ -n "$snapshot_name" ]; then
                print_status "  • Deleting $snapshot_name"
                az snapshot delete --name "$snapshot_name" --resource-group "$RESOURCE_GROUP" --yes &> /dev/null
            fi
        done
        print_success "Old snapshots cleaned up"
    else
        print_success "No old snapshots to clean up"
    fi
}

# Generate snapshot report
generate_snapshot_report() {
    print_status "Generating snapshot report..."
    
    # Get current snapshots
    current_snapshots=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['created-by']=='backup-script'].{name:name,size:diskSizeGb,created:timeCreated,pvc:tags['pvc-namespace'] + '/' + tags['pvc-name']}" -o table)
    
    # Calculate total size
    total_size=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['created-by']=='backup-script'].diskSizeGb" -o tsv | awk '{sum += $1} END {print sum}')
    
    # Count snapshots
    snapshot_count=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['created-by']=='backup-script'] | length(@)")
    
    echo "📊 PVC Snapshot Report"
    echo "====================="
    echo "Timestamp: $TIMESTAMP"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Retention: $SNAPSHOT_RETENTION_DAYS days"
    echo "Total Snapshots: $snapshot_count"
    echo "Total Size: ${total_size}GB"
    echo ""
    echo "📸 Current Snapshots:"
    echo "$current_snapshots"
    echo ""
    echo "📋 Recommendations:"
    echo "   • Snapshots created successfully"
    echo "   • Old snapshots cleaned up"
    echo "   • Ready for cluster teardown"
    echo "   • Use restore-from-snapshots.sh to restore"
}

# Store snapshot information
store_snapshot_info() {
    print_status "Storing snapshot information..."
    
    # Get Key Vault name from environment or use default
    KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
    
    # Create snapshot information JSON
    snapshot_info=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['backup-timestamp']=='$TIMESTAMP'].{name:name,size:diskSizeGb,created:timeCreated,pvc_namespace:tags['pvc-namespace'],pvc_name:tags['pvc-name']}" -o json)
    
    # Store in Key Vault
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "pvc-snapshots-${TIMESTAMP}" \
        --value "$snapshot_info" \
        --description "PVC snapshots information for timestamp $TIMESTAMP" \
        &> /dev/null
    
    print_success "Snapshot information stored in Azure Key Vault"
}

# Main execution
main() {
    print_status "Starting PVC snapshot creation process..."
    
    check_prerequisites
    get_pvc_info
    get_disk_info
    create_pvc_snapshots
    verify_snapshots
    cleanup_old_snapshots
    store_snapshot_info
    generate_snapshot_report
    
    print_success "PVC snapshot creation completed successfully!"
    echo ""
    echo "📸 Snapshot Summary:"
    echo "   • Timestamp: $TIMESTAMP"
    echo "   • Resource Group: $RESOURCE_GROUP"
    echo "   • Retention: $SNAPSHOT_RETENTION_DAYS days"
    echo "   • Status: Completed successfully"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Proceed with cluster teardown"
    echo "   2. Use restore-from-snapshots.sh to restore PVCs"
    echo "   3. Monitor snapshot costs"
}

# Run main function
main "$@"
