#!/bin/bash
# PVC Restore Script
# Restores PVCs from Azure disk snapshots

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

print_status "📸 Starting PVC restore from snapshots"

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-rocketchat-k8s-rg}"
NAMESPACE="${NAMESPACE:-rocketchat}"
SNAPSHOT_TIMESTAMP="${SNAPSHOT_TIMESTAMP:-}"
RESTORE_NAMESPACE="${RESTORE_NAMESPACE:-rocketchat}"

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

# List available snapshots
list_available_snapshots() {
    print_status "Listing available snapshots..."
    
    # List snapshots with backup tags
    snapshots=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['created-by']=='backup-script'].{name:name,created:timeCreated,pvc:tags['pvc-namespace'] + '/' + tags['pvc-name'],size:diskSizeGb}" -o table)
    
    if [ -n "$snapshots" ]; then
        print_status "Available snapshots:"
        echo "$snapshots"
    else
        print_error "No snapshots found with backup tags"
        exit 1
    fi
    
    # If no timestamp specified, get the latest
    if [ -z "$SNAPSHOT_TIMESTAMP" ]; then
        SNAPSHOT_TIMESTAMP=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "max_by([?tags['created-by']=='backup-script'], &timeCreated).tags['backup-timestamp']" -o tsv)
        
        if [ -z "$SNAPSHOT_TIMESTAMP" ]; then
            print_error "No snapshots found"
            exit 1
        fi
        
        print_status "Using latest snapshot timestamp: $SNAPSHOT_TIMESTAMP"
    fi
    
    print_success "Snapshot timestamp selected: $SNAPSHOT_TIMESTAMP"
}

# Get snapshot information
get_snapshot_info() {
    print_status "Getting snapshot information..."
    
    # Get snapshots for the specified timestamp
    snapshots=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "[?tags['backup-timestamp']=='$SNAPSHOT_TIMESTAMP'].{name:name,size:diskSizeGb,created:timeCreated,pvc_namespace:tags['pvc-namespace'],pvc_name:tags['pvc-name']}" -o json)
    
    if [ -z "$snapshots" ] || [ "$snapshots" = "[]" ]; then
        print_error "No snapshots found for timestamp $SNAPSHOT_TIMESTAMP"
        exit 1
    fi
    
    print_status "Found snapshots for timestamp $SNAPSHOT_TIMESTAMP:"
    echo "$snapshots" | jq -r '.[] | "  • \(.name) -> \(.pvc_namespace)/\(.pvc_name) (\(.size)GB)"'
    
    print_success "Snapshot information retrieved"
}

# Create namespace if it doesn't exist
create_namespace() {
    print_status "Creating namespace '$RESTORE_NAMESPACE' if it doesn't exist..."
    kubectl create namespace "$RESTORE_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace '$RESTORE_NAMESPACE' ready"
}

# Restore PVCs from snapshots
restore_pvcs_from_snapshots() {
    print_status "Restoring PVCs from snapshots..."
    
    # Process each snapshot
    echo "$snapshots" | jq -r '.[] | "\(.name)|\(.pvc_namespace)|\(.pvc_name)|\(.size)"' | while IFS='|' read -r snapshot_name pvc_namespace pvc_name disk_size; do
        if [ -n "$snapshot_name" ]; then
            print_status "Restoring PVC $pvc_namespace/$pvc_name from snapshot $snapshot_name..."
            
            # Create disk from snapshot
            disk_name="${pvc_name}-restored-$(date +%Y%m%d%H%M%S)"
            
            if az disk create \
                --name "$disk_name" \
                --resource-group "$RESOURCE_GROUP" \
                --source "$snapshot_name" \
                --sku "Premium_LRS" \
                &> /dev/null; then
                print_success "Disk created from snapshot: $disk_name"
                
                # Create PVC manifest
                create_pvc_manifest "$pvc_name" "$disk_name" "$disk_size"
            else
                print_error "Failed to create disk from snapshot $snapshot_name"
            fi
        fi
    done
    
    print_success "PVCs restored from snapshots"
}

# Create PVC manifest
create_pvc_manifest() {
    local pvc_name="$1"
    local disk_name="$2"
    local disk_size="$3"
    
    print_status "Creating PVC manifest for $pvc_name..."
    
    # Create PVC manifest
    cat > "/tmp/${pvc_name}-pvc.yaml" << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $pvc_name
  namespace: $RESTORE_NAMESPACE
  labels:
    app: restored
    backup-timestamp: $SNAPSHOT_TIMESTAMP
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: ${disk_size}Gi
  storageClassName: premium-ssd
  volumeName: $disk_name
EOF
    
    # Apply PVC manifest
    kubectl apply -f "/tmp/${pvc_name}-pvc.yaml"
    
    # Clean up manifest
    rm -f "/tmp/${pvc_name}-pvc.yaml"
    
    print_success "PVC manifest created and applied for $pvc_name"
}

# Create PV manifest
create_pv_manifest() {
    local pvc_name="$1"
    local disk_name="$2"
    local disk_size="$3"
    
    print_status "Creating PV manifest for $pvc_name..."
    
    # Get disk resource ID
    disk_id=$(az disk show --name "$disk_name" --resource-group "$RESOURCE_GROUP" --query id -o tsv)
    
    # Create PV manifest
    cat > "/tmp/${pvc_name}-pv.yaml" << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: $disk_name
  labels:
    app: restored
    backup-timestamp: $SNAPSHOT_TIMESTAMP
spec:
  capacity:
    storage: ${disk_size}Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: premium-ssd
  azureDisk:
    diskName: $disk_name
    diskURI: $disk_id
    cachingMode: ReadWrite
    fsType: ext4
  claimRef:
    name: $pvc_name
    namespace: $RESTORE_NAMESPACE
EOF
    
    # Apply PV manifest
    kubectl apply -f "/tmp/${pvc_name}-pv.yaml"
    
    # Clean up manifest
    rm -f "/tmp/${pvc_name}-pv.yaml"
    
    print_success "PV manifest created and applied for $pvc_name"
}

# Restore all PVCs and PVs
restore_all_pvcs_and_pvs() {
    print_status "Restoring all PVCs and PVs..."
    
    # Process each snapshot
    echo "$snapshots" | jq -r '.[] | "\(.name)|\(.pvc_namespace)|\(.pvc_name)|\(.size)"' | while IFS='|' read -r snapshot_name pvc_namespace pvc_name disk_size; do
        if [ -n "$snapshot_name" ]; then
            print_status "Restoring PVC $pvc_namespace/$pvc_name from snapshot $snapshot_name..."
            
            # Create disk from snapshot
            disk_name="${pvc_name}-restored-$(date +%Y%m%d%H%M%S)"
            
            if az disk create \
                --name "$disk_name" \
                --resource-group "$RESOURCE_GROUP" \
                --source "$snapshot_name" \
                --sku "Premium_LRS" \
                &> /dev/null; then
                print_success "Disk created from snapshot: $disk_name"
                
                # Create PV and PVC manifests
                create_pv_manifest "$pvc_name" "$disk_name" "$disk_size"
                create_pvc_manifest "$pvc_name" "$disk_name" "$disk_size"
            else
                print_error "Failed to create disk from snapshot $snapshot_name"
            fi
        fi
    done
    
    print_success "All PVCs and PVs restored"
}

# Verify restore
verify_restore() {
    print_status "Verifying restore..."
    
    # Check PVCs
    print_status "Checking PVCs in namespace '$RESTORE_NAMESPACE':"
    kubectl get pvc -n "$RESTORE_NAMESPACE" -o wide
    
    # Check PVs
    print_status "Checking PVs:"
    kubectl get pv -o wide | grep "backup-timestamp=$SNAPSHOT_TIMESTAMP"
    
    # Check disk status
    print_status "Checking Azure disks:"
    az disk list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'restored')].{name:name,size:diskSizeGb,state:diskState}" -o table
    
    print_success "Restore verification completed"
}

# Generate restore report
generate_restore_report() {
    print_status "Generating restore report..."
    
    # Get restored PVCs
    restored_pvcs=$(kubectl get pvc -n "$RESTORE_NAMESPACE" -o json | jq -r '.items[] | "\(.metadata.name) \(.spec.resources.requests.storage) \(.status.phase)"')
    
    # Get restored PVs
    restored_pvs=$(kubectl get pv -o json | jq -r '.items[] | select(.metadata.labels["backup-timestamp"] == "'$SNAPSHOT_TIMESTAMP'") | "\(.metadata.name) \(.spec.capacity.storage) \(.status.phase)"')
    
    echo "📊 PVC Restore Report"
    echo "===================="
    echo "Snapshot Timestamp: $SNAPSHOT_TIMESTAMP"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Restore Namespace: $RESTORE_NAMESPACE"
    echo ""
    echo "📸 Restored PVCs:"
    echo "$restored_pvcs" | while read -r name size phase; do
        echo "  • $name ($size, $phase)"
    done
    echo ""
    echo "💾 Restored PVs:"
    echo "$restored_pvs" | while read -r name size phase; do
        echo "  • $name ($size, $phase)"
    done
    echo ""
    echo "📋 Next steps:"
    echo "   • Deploy applications to use restored PVCs"
    echo "   • Verify data integrity"
    echo "   • Monitor disk usage and performance"
}

# Main execution
main() {
    print_status "Starting PVC restore process..."
    
    check_prerequisites
    list_available_snapshots
    get_snapshot_info
    create_namespace
    restore_all_pvcs_and_pvs
    verify_restore
    generate_restore_report
    
    print_success "PVC restore completed successfully!"
    echo ""
    echo "📸 Restore Summary:"
    echo "   • Snapshot Timestamp: $SNAPSHOT_TIMESTAMP"
    echo "   • Resource Group: $RESOURCE_GROUP"
    echo "   • Restore Namespace: $RESTORE_NAMESPACE"
    echo "   • Status: Completed successfully"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Deploy applications to use restored PVCs"
    echo "   2. Verify data integrity"
    echo "   3. Monitor disk usage and performance"
}

# Run main function
main "$@"
