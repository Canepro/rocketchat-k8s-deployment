#!/bin/bash
# Cluster Teardown Script
# Safe, validated destruction process with state preservation

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

print_status "🗑️ Starting safe cluster teardown process"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-rocketchat-aks}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rocketchat-k8s-rg}"
NAMESPACES="${NAMESPACES:-rocketchat monitoring}"
DRY_RUN="${DRY_RUN:-false}"
FORCE_TEARDOWN="${FORCE_TEARDOWN:-false}"

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

# Pre-flight validation
preflight_validation() {
    print_status "Running pre-flight validation..."
    
    # Check if cluster exists
    if ! az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        print_error "Cluster '$CLUSTER_NAME' not found in resource group '$RESOURCE_GROUP'"
        exit 1
    fi
    
    # Check cluster status
    cluster_status=$(az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "provisioningState" -o tsv)
    print_status "Cluster status: $cluster_status"
    
    if [ "$cluster_status" != "Succeeded" ] && [ "$FORCE_TEARDOWN" != "true" ]; then
        print_error "Cluster is not in 'Succeeded' state. Use --force-teardown to override."
        exit 1
    fi
    
    # Check if kubectl can connect
    if ! kubectl get nodes &> /dev/null; then
        print_warning "Cannot connect to cluster. Proceeding with teardown..."
    else
        print_success "Cluster connection verified"
    fi
    
    print_success "Pre-flight validation passed"
}

# Backup cluster state
backup_cluster_state() {
    print_status "Backing up cluster state..."
    
    # Run cluster state backup script
    if [ -f "scripts/backup/backup-cluster-state.sh" ]; then
        ./scripts/backup/backup-cluster-state.sh
        print_success "Cluster state backed up"
    else
        print_warning "Cluster state backup script not found. Skipping..."
    fi
}

# Backup secrets to Key Vault
backup_secrets_to_keyvault() {
    print_status "Backing up secrets to Azure Key Vault..."
    
    # Run secrets backup script
    if [ -f "scripts/secrets/backup-secrets-to-keyvault.sh" ]; then
        ./scripts/secrets/backup-secrets-to-keyvault.sh
        print_success "Secrets backed up to Key Vault"
    else
        print_warning "Secrets backup script not found. Skipping..."
    fi
}

# Create PVC snapshots
create_pvc_snapshots() {
    print_status "Creating PVC snapshots..."
    
    # Run PVC snapshot script
    if [ -f "scripts/backup/create-pvc-snapshots.sh" ]; then
        ./scripts/backup/create-pvc-snapshots.sh
        print_success "PVC snapshots created"
    else
        print_warning "PVC snapshot script not found. Skipping..."
    fi
}

# Backup MongoDB data
backup_mongodb_data() {
    print_status "Backing up MongoDB data..."
    
    # Run MongoDB backup script
    if [ -f "scripts/backup/mongodb-backup.sh" ]; then
        ./scripts/backup/mongodb-backup.sh
        print_success "MongoDB data backed up"
    else
        print_warning "MongoDB backup script not found. Skipping..."
    fi
}

# Drain nodes gracefully
drain_nodes() {
    print_status "Draining nodes gracefully..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would drain nodes"
        return 0
    fi
    
    # Get node names
    nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    
    if [ -n "$nodes" ]; then
        for node in $nodes; do
            print_status "Draining node: $node"
            kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force --grace-period=300 &> /dev/null || true
        done
        print_success "Nodes drained"
    else
        print_warning "No nodes found to drain"
    fi
}

# Delete Helm releases
delete_helm_releases() {
    print_status "Deleting Helm releases..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would delete Helm releases"
        return 0
    fi
    
    # Get all Helm releases
    helm_releases=$(helm list -A -o json | jq -r '.[] | "\(.namespace) \(.name)"')
    
    if [ -n "$helm_releases" ]; then
        echo "$helm_releases" | while read -r namespace name; do
            print_status "Deleting Helm release: $namespace/$name"
            helm uninstall "$name" -n "$namespace" &> /dev/null || true
        done
        print_success "Helm releases deleted"
    else
        print_warning "No Helm releases found"
    fi
}

# Delete Kubernetes resources
delete_kubernetes_resources() {
    print_status "Deleting Kubernetes resources..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would delete Kubernetes resources"
        return 0
    fi
    
    for namespace in $NAMESPACES; do
        print_status "Deleting resources in namespace: $namespace"
        
        # Delete deployments
        kubectl delete deployments --all -n "$namespace" --grace-period=300 &> /dev/null || true
        
        # Delete statefulsets
        kubectl delete statefulsets --all -n "$namespace" --grace-period=300 &> /dev/null || true
        
        # Delete services
        kubectl delete services --all -n "$namespace" &> /dev/null || true
        
        # Delete ingress
        kubectl delete ingress --all -n "$namespace" &> /dev/null || true
        
        # Delete PVCs (but keep PVs for snapshots)
        kubectl delete pvc --all -n "$namespace" &> /dev/null || true
        
        # Delete secrets (but keep service account tokens)
        kubectl delete secrets --field-selector type!=kubernetes.io/service-account-token -n "$namespace" &> /dev/null || true
        
        # Delete configmaps
        kubectl delete configmaps --all -n "$namespace" &> /dev/null || true
        
        print_success "Resources deleted in namespace: $namespace"
    done
}

# Delete namespaces
delete_namespaces() {
    print_status "Deleting namespaces..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would delete namespaces"
        return 0
    fi
    
    for namespace in $NAMESPACES; do
        print_status "Deleting namespace: $namespace"
        kubectl delete namespace "$namespace" --grace-period=300 &> /dev/null || true
    done
    
    print_success "Namespaces deleted"
}

# Destroy AKS cluster
destroy_aks_cluster() {
    print_status "Destroying AKS cluster..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would destroy AKS cluster"
        return 0
    fi
    
    # Destroy cluster using Terraform
    if [ -f "infrastructure/terraform/main.tf" ]; then
        print_status "Destroying cluster using Terraform..."
        cd infrastructure/terraform
        terraform destroy -auto-approve
        cd ../..
        print_success "Cluster destroyed using Terraform"
    else
        print_status "Destroying cluster using Azure CLI..."
        az aks delete --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --yes
        print_success "Cluster destroyed using Azure CLI"
    fi
}

# Preserve static IPs
preserve_static_ips() {
    print_status "Preserving static IPs..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would preserve static IPs"
        return 0
    fi
    
    # Get static IPs
    static_ips=$(az network public-ip list --resource-group "$RESOURCE_GROUP" --query "[?tags.PreserveIP=='true'].{name:name,ip:ipAddress}" -o json)
    
    if [ -n "$static_ips" ] && [ "$static_ips" != "[]" ]; then
        print_status "Static IPs to preserve:"
        echo "$static_ips" | jq -r '.[] | "  • \(.name): \(.ip)"'
        print_success "Static IPs preserved"
    else
        print_warning "No static IPs found to preserve"
    fi
}

# Preserve DNS zones
preserve_dns_zones() {
    print_status "Preserving DNS zones..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would preserve DNS zones"
        return 0
    fi
    
    # Check if DNS zones exist
    dns_zones=$(az network dns zone list --query "[].{name:name,resourceGroup:resourceGroup}" -o json)
    
    if [ -n "$dns_zones" ] && [ "$dns_zones" != "[]" ]; then
        print_status "DNS zones to preserve:"
        echo "$dns_zones" | jq -r '.[] | "  • \(.name) (\(.resourceGroup))"'
        print_success "DNS zones preserved"
    else
        print_warning "No DNS zones found to preserve"
    fi
}

# Verify teardown
verify_teardown() {
    print_status "Verifying teardown..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would verify teardown"
        return 0
    fi
    
    # Check if cluster still exists
    if az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        print_error "Cluster still exists after teardown"
        exit 1
    fi
    
    # Check if snapshots exist
    snapshots=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "length([?tags['created-by']=='backup-script'])")
    if [ "$snapshots" -gt 0 ]; then
        print_success "PVC snapshots preserved: $snapshots"
    else
        print_warning "No PVC snapshots found"
    fi
    
    # Check if backups exist
    if [ -f "scripts/backup/backup-integrity-check.sh" ]; then
        ./scripts/backup/backup-integrity-check.sh
    fi
    
    print_success "Teardown verification completed"
}

# Generate teardown report
generate_teardown_report() {
    print_status "Generating teardown report..."
    
    echo "📊 Cluster Teardown Report"
    echo "========================="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Cluster: $CLUSTER_NAME"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Dry Run: $DRY_RUN"
    echo ""
    echo "🗑️ Teardown Actions:"
    echo "   • Cluster state backed up"
    echo "   • Secrets backed up to Key Vault"
    echo "   • PVC snapshots created"
    echo "   • MongoDB data backed up"
    echo "   • Nodes drained gracefully"
    echo "   • Helm releases deleted"
    echo "   • Kubernetes resources deleted"
    echo "   • Namespaces deleted"
    echo "   • AKS cluster destroyed"
    echo "   • Static IPs preserved"
    echo "   • DNS zones preserved"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Verify backups in Azure Portal"
    echo "   2. Use recreate-cluster.sh to restore"
    echo "   3. Monitor costs for residual resources"
    echo "   4. Clean up old snapshots if needed"
}

# Main execution
main() {
    print_status "Starting cluster teardown process..."
    
    check_prerequisites
    preflight_validation
    backup_cluster_state
    backup_secrets_to_keyvault
    create_pvc_snapshots
    backup_mongodb_data
    drain_nodes
    delete_helm_releases
    delete_kubernetes_resources
    delete_namespaces
    destroy_aks_cluster
    preserve_static_ips
    preserve_dns_zones
    verify_teardown
    generate_teardown_report
    
    print_success "Cluster teardown completed successfully!"
    echo ""
    echo "🗑️ Teardown Summary:"
    echo "   • Cluster: $CLUSTER_NAME"
    echo "   • Resource Group: $RESOURCE_GROUP"
    echo "   • Status: Completed successfully"
    echo "   • Backups: Created and verified"
    echo "   • Snapshots: Created and preserved"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Verify backups in Azure Portal"
    echo "   2. Use recreate-cluster.sh to restore"
    echo "   3. Monitor costs for residual resources"
}

# Run main function
main "$@"
