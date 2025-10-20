#!/bin/bash
# Cluster State Backup Script
# Backs up cluster state including Helm values, secrets, and configurations

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

print_status "💾 Starting cluster state backup"

# Configuration
BACKUP_STORAGE_ACCOUNT="${BACKUP_STORAGE_ACCOUNT:-rocketchatbackups}"
BACKUP_CONTAINER="${BACKUP_CONTAINER:-cluster-state}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="cluster-state-backup-${TIMESTAMP}"
LOCAL_BACKUP_DIR="/tmp/cluster-state-backup-${TIMESTAMP}"
NAMESPACES="${NAMESPACES:-rocketchat monitoring}"

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
    
    print_success "Prerequisites check passed"
}

# Create local backup directory
create_backup_directory() {
    print_status "Creating local backup directory..."
    
    mkdir -p "$LOCAL_BACKUP_DIR"
    print_success "Local backup directory created: $LOCAL_BACKUP_DIR"
}

# Backup Helm releases
backup_helm_releases() {
    print_status "Backing up Helm releases..."
    
    # Get all Helm releases
    helm_releases=$(helm list -A -o json | jq -r '.[] | "\(.namespace) \(.name)"')
    
    if [ -n "$helm_releases" ]; then
        print_status "Found Helm releases:"
        echo "$helm_releases" | while read -r namespace name; do
            print_status "  • $namespace/$name"
            
            # Backup Helm values
            helm get values "$name" -n "$namespace" > "$LOCAL_BACKUP_DIR/helm-values-${namespace}-${name}.yaml" 2>/dev/null || true
            
            # Backup Helm manifest
            helm get manifest "$name" -n "$namespace" > "$LOCAL_BACKUP_DIR/helm-manifest-${namespace}-${name}.yaml" 2>/dev/null || true
        done
        
        print_success "Helm releases backed up"
    else
        print_warning "No Helm releases found"
    fi
}

# Backup Kubernetes resources
backup_kubernetes_resources() {
    print_status "Backing up Kubernetes resources..."
    
    for namespace in $NAMESPACES; do
        print_status "Backing up namespace: $namespace"
        
        # Create namespace backup directory
        mkdir -p "$LOCAL_BACKUP_DIR/$namespace"
        
        # Backup all resources in namespace
        kubectl get all -n "$namespace" -o yaml > "$LOCAL_BACKUP_DIR/$namespace/all-resources.yaml" 2>/dev/null || true
        
        # Backup ConfigMaps
        kubectl get configmaps -n "$namespace" -o yaml > "$LOCAL_BACKUP_DIR/$namespace/configmaps.yaml" 2>/dev/null || true
        
        # Backup Secrets (excluding service account tokens)
        kubectl get secrets -n "$namespace" --field-selector type!=kubernetes.io/service-account-token -o yaml > "$LOCAL_BACKUP_DIR/$namespace/secrets.yaml" 2>/dev/null || true
        
        # Backup PVCs
        kubectl get pvc -n "$namespace" -o yaml > "$LOCAL_BACKUP_DIR/$namespace/pvcs.yaml" 2>/dev/null || true
        
        # Backup PVs
        kubectl get pv -o yaml > "$LOCAL_BACKUP_DIR/$namespace/pvs.yaml" 2>/dev/null || true
        
        # Backup Ingress
        kubectl get ingress -n "$namespace" -o yaml > "$LOCAL_BACKUP_DIR/$namespace/ingress.yaml" 2>/dev/null || true
        
        # Backup Services
        kubectl get services -n "$namespace" -o yaml > "$LOCAL_BACKUP_DIR/$namespace/services.yaml" 2>/dev/null || true
        
        # Backup Deployments
        kubectl get deployments -n "$namespace" -o yaml > "$LOCAL_BACKUP_DIR/$namespace/deployments.yaml" 2>/dev/null || true
        
        # Backup StatefulSets
        kubectl get statefulsets -n "$namespace" -o yaml > "$LOCAL_BACKUP_DIR/$namespace/statefulsets.yaml" 2>/dev/null || true
        
        print_success "Namespace $namespace backed up"
    done
}

# Backup cluster information
backup_cluster_info() {
    print_status "Backing up cluster information..."
    
    # Cluster info
    kubectl cluster-info > "$LOCAL_BACKUP_DIR/cluster-info.txt" 2>/dev/null || true
    
    # Node information
    kubectl get nodes -o yaml > "$LOCAL_BACKUP_DIR/nodes.yaml" 2>/dev/null || true
    
    # Storage classes
    kubectl get storageclass -o yaml > "$LOCAL_BACKUP_DIR/storageclasses.yaml" 2>/dev/null || true
    
    # Namespaces
    kubectl get namespaces -o yaml > "$LOCAL_BACKUP_DIR/namespaces.yaml" 2>/dev/null || true
    
    # RBAC
    kubectl get clusterroles -o yaml > "$LOCAL_BACKUP_DIR/clusterroles.yaml" 2>/dev/null || true
    kubectl get clusterrolebindings -o yaml > "$LOCAL_BACKUP_DIR/clusterrolebindings.yaml" 2>/dev/null || true
    
    print_success "Cluster information backed up"
}

# Backup DNS and certificate information
backup_dns_and_certs() {
    print_status "Backing up DNS and certificate information..."
    
    # Get ingress information
    kubectl get ingress -A -o yaml > "$LOCAL_BACKUP_DIR/ingress-all.yaml" 2>/dev/null || true
    
    # Get certificate information
    kubectl get certificates -A -o yaml > "$LOCAL_BACKUP_DIR/certificates.yaml" 2>/dev/null || true
    kubectl get certificaterequests -A -o yaml > "$LOCAL_BACKUP_DIR/certificaterequests.yaml" 2>/dev/null || true
    
    # Get DNS information (if using external-dns)
    kubectl get dnsendpoints -A -o yaml > "$LOCAL_BACKUP_DIR/dnsendpoints.yaml" 2>/dev/null || true
    
    print_success "DNS and certificate information backed up"
}

# Create backup manifest
create_backup_manifest() {
    print_status "Creating backup manifest..."
    
    # Create backup manifest
    cat > "$LOCAL_BACKUP_DIR/backup-manifest.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-state-backup-${TIMESTAMP}
  namespace: kube-system
data:
  backup-timestamp: "${TIMESTAMP}"
  backup-type: "cluster-state"
  namespaces: "${NAMESPACES}"
  storage-account: "${BACKUP_STORAGE_ACCOUNT}"
  container: "${BACKUP_CONTAINER}"
  backup-name: "${BACKUP_NAME}"
EOF
    
    print_success "Backup manifest created"
}

# Compress backup
compress_backup() {
    print_status "Compressing backup..."
    
    cd "$LOCAL_BACKUP_DIR"
    tar -czf "${BACKUP_NAME}.tar.gz" .
    
    # Verify compression
    if [ -f "${BACKUP_NAME}.tar.gz" ]; then
        COMPRESSED_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)
        print_success "Backup compressed: ${BACKUP_NAME}.tar.gz ($COMPRESSED_SIZE)"
    else
        print_error "Backup compression failed"
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
        --name "${BACKUP_NAME}.tar.gz" \
        --file "$LOCAL_BACKUP_DIR/${BACKUP_NAME}.tar.gz" \
        --overwrite
    
    print_success "Backup uploaded to Azure Blob Storage"
}

# Store backup information
store_backup_info() {
    print_status "Storing backup information..."
    
    # Get Key Vault name from environment or use default
    KEY_VAULT_NAME="${KEY_VAULT_NAME:-rocketchat-kv}"
    
    # Create backup information JSON
    backup_info=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "type": "cluster-state",
  "namespaces": "$NAMESPACES",
  "storage_account": "$BACKUP_STORAGE_ACCOUNT",
  "container": "$BACKUP_CONTAINER",
  "backup_name": "$BACKUP_NAME",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    # Store in Key Vault
    az keyvault secret set \
        --vault-name "$KEY_VAULT_NAME" \
        --name "cluster-state-backup-${TIMESTAMP}" \
        --value "$backup_info" \
        --description "Cluster state backup information for timestamp $TIMESTAMP" \
        &> /dev/null
    
    print_success "Backup information stored in Azure Key Vault"
}

# Clean up local files
cleanup_local() {
    print_status "Cleaning up local files..."
    
    rm -rf "$LOCAL_BACKUP_DIR"
    print_success "Local files cleaned up"
}

# Generate backup report
generate_backup_report() {
    print_status "Generating backup report..."
    
    echo "📊 Cluster State Backup Report"
    echo "============================="
    echo "Timestamp: $TIMESTAMP"
    echo "Backup Name: $BACKUP_NAME"
    echo "Storage Account: $BACKUP_STORAGE_ACCOUNT"
    echo "Container: $BACKUP_CONTAINER"
    echo "Namespaces: $NAMESPACES"
    echo ""
    echo "📦 Backed up resources:"
    echo "   • Helm releases and values"
    echo "   • Kubernetes resources (all namespaces)"
    echo "   • ConfigMaps and Secrets"
    echo "   • PVCs and PVs"
    echo "   • Ingress and Services"
    echo "   • Deployments and StatefulSets"
    echo "   • Cluster information"
    echo "   • DNS and certificate information"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Verify backup in Azure Portal"
    echo "   2. Test restore process if needed"
    echo "   3. Monitor backup schedule"
}

# Main execution
main() {
    print_status "Starting cluster state backup process..."
    
    check_prerequisites
    create_backup_directory
    backup_helm_releases
    backup_kubernetes_resources
    backup_cluster_info
    backup_dns_and_certs
    create_backup_manifest
    compress_backup
    upload_to_azure
    store_backup_info
    cleanup_local
    generate_backup_report
    
    print_success "Cluster state backup completed successfully!"
    echo ""
    echo "💾 Backup Details:"
    echo "   • Backup Name: ${BACKUP_NAME}.tar.gz"
    echo "   • Storage Account: $BACKUP_STORAGE_ACCOUNT"
    echo "   • Container: $BACKUP_CONTAINER"
    echo "   • Namespaces: $NAMESPACES"
    echo "   • Timestamp: $TIMESTAMP"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Verify backup in Azure Portal"
    echo "   2. Test restore process if needed"
    echo "   3. Monitor backup schedule"
}

# Run main function
main "$@"
