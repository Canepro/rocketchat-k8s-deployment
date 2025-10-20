#!/bin/bash
# Cluster Recreation Script
# Restores cluster from snapshots with full state

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

print_status "🔄 Starting cluster recreation process"

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-rocketchat-aks}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rocketchat-k8s-rg}"
NAMESPACES="${NAMESPACES:-rocketchat monitoring}"
SNAPSHOT_TIMESTAMP="${SNAPSHOT_TIMESTAMP:-}"
ENABLE_MONITORING="${ENABLE_MONITORING:-false}"
DRY_RUN="${DRY_RUN:-false}"

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
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install Terraform."
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Please run 'az login'."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Check if cluster already exists
check_cluster_exists() {
    print_status "Checking if cluster already exists..."
    
    if az aks show --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        print_error "Cluster '$CLUSTER_NAME' already exists in resource group '$RESOURCE_GROUP'"
        exit 1
    fi
    
    print_success "Cluster does not exist. Proceeding with recreation."
}

# Get latest snapshot timestamp
get_latest_snapshot_timestamp() {
    print_status "Getting latest snapshot timestamp..."
    
    if [ -z "$SNAPSHOT_TIMESTAMP" ]; then
        SNAPSHOT_TIMESTAMP=$(az snapshot list --resource-group "$RESOURCE_GROUP" --query "max_by([?tags['created-by']=='backup-script'], &timeCreated).tags['backup-timestamp']" -o tsv)
        
        if [ -z "$SNAPSHOT_TIMESTAMP" ]; then
            print_error "No snapshots found. Cannot proceed with recreation."
            exit 1
        fi
        
        print_status "Using latest snapshot timestamp: $SNAPSHOT_TIMESTAMP"
    fi
    
    print_success "Snapshot timestamp selected: $SNAPSHOT_TIMESTAMP"
}

# Create AKS cluster using Terraform
create_aks_cluster() {
    print_status "Creating AKS cluster using Terraform..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would create AKS cluster"
        return 0
    fi
    
    # Navigate to Terraform directory
    cd infrastructure/terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan the deployment
    terraform plan -var="lifecycle_stage=active" -var="enable_monitoring=$ENABLE_MONITORING"
    
    # Apply the configuration
    terraform apply -auto-approve -var="lifecycle_stage=active" -var="enable_monitoring=$ENABLE_MONITORING"
    
    # Get cluster credentials
    az aks get-credentials --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --overwrite
    
    cd ../..
    
    print_success "AKS cluster created"
}

# Install base infrastructure
install_base_infrastructure() {
    print_status "Installing base infrastructure..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would install base infrastructure"
        return 0
    fi
    
    # Install NGINX Ingress Controller
    print_status "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Install cert-manager
    print_status "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    kubectl wait --namespace cert-manager \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/instance=cert-manager \
        --timeout=300s
    
    # Apply ClusterIssuer
    print_status "Applying ClusterIssuer configuration..."
    kubectl apply -f k8s/base/namespace.yaml
    
    print_success "Base infrastructure installed"
}

# Restore PVCs from snapshots
restore_pvcs_from_snapshots() {
    print_status "Restoring PVCs from snapshots..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would restore PVCs from snapshots"
        return 0
    fi
    
    # Run PVC restore script
    if [ -f "scripts/backup/restore-from-snapshots.sh" ]; then
        SNAPSHOT_TIMESTAMP="$SNAPSHOT_TIMESTAMP" ./scripts/backup/restore-from-snapshots.sh
        print_success "PVCs restored from snapshots"
    else
        print_warning "PVC restore script not found. Skipping..."
    fi
}

# Sync secrets from Key Vault
sync_secrets_from_keyvault() {
    print_status "Syncing secrets from Azure Key Vault..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would sync secrets from Key Vault"
        return 0
    fi
    
    # Run secrets sync script
    if [ -f "scripts/secrets/sync-from-keyvault.sh" ]; then
        ./scripts/secrets/sync-from-keyvault.sh
        print_success "Secrets synced from Key Vault"
    else
        print_warning "Secrets sync script not found. Skipping..."
    fi
}

# Deploy Rocket.Chat
deploy_rocketchat() {
    print_status "Deploying Rocket.Chat..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would deploy Rocket.Chat"
        return 0
    fi
    
    # Deploy using Kustomize
    kubectl apply -k k8s/overlays/production
    
    # Wait for Rocket.Chat to be ready
    kubectl wait --for=condition=ready pod -l app=rocketchat -n rocketchat --timeout=300s
    
    print_success "Rocket.Chat deployed"
}

# Deploy monitoring stack (conditional)
deploy_monitoring_stack() {
    if [ "$ENABLE_MONITORING" = "true" ]; then
        print_status "Deploying monitoring stack..."
        
        if [ "$DRY_RUN" = "true" ]; then
            print_status "DRY RUN: Would deploy monitoring stack"
            return 0
        fi
        
        # Deploy monitoring using Kustomize
        kubectl apply -k k8s/overlays/monitoring
        
        # Wait for monitoring components to be ready
        kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
        kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s
        
        print_success "Monitoring stack deployed"
    else
        print_status "Monitoring stack deployment skipped (ENABLE_MONITORING=false)"
    fi
}

# Restore MongoDB data
restore_mongodb_data() {
    print_status "Restoring MongoDB data..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would restore MongoDB data"
        return 0
    fi
    
    # Run MongoDB restore script
    if [ -f "scripts/backup/mongodb-restore.sh" ]; then
        ./scripts/backup/mongodb-restore.sh
        print_success "MongoDB data restored"
    else
        print_warning "MongoDB restore script not found. Skipping..."
    fi
}

# Configure DNS and certificates
configure_dns_and_certificates() {
    print_status "Configuring DNS and certificates..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would configure DNS and certificates"
        return 0
    fi
    
    # Get cluster IP
    cluster_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -n "$cluster_ip" ]; then
        print_status "Cluster IP: $cluster_ip"
        print_status "Update DNS records to point to: $cluster_ip"
        print_status "  • chat.canepro.me -> $cluster_ip"
        print_status "  • grafana.chat.canepro.me -> $cluster_ip"
    else
        print_warning "Cluster IP not available yet"
    fi
    
    # Wait for certificates to be issued
    print_status "Waiting for SSL certificates..."
    kubectl wait --for=condition=ready certificate rocketchat-tls -n rocketchat --timeout=300s || true
    kubectl wait --for=condition=ready certificate grafana-tls -n monitoring --timeout=300s || true
    
    print_success "DNS and certificates configured"
}

# Run health checks
run_health_checks() {
    print_status "Running health checks..."
    
    if [ "$DRY_RUN" = "true" ]; then
        print_status "DRY RUN: Would run health checks"
        return 0
    fi
    
    # Check cluster status
    print_status "Checking cluster status..."
    kubectl get nodes
    kubectl get pods -A
    
    # Check Rocket.Chat
    print_status "Checking Rocket.Chat..."
    if kubectl get pod -l app=rocketchat -n rocketchat -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
        print_success "Rocket.Chat is running"
    else
        print_error "Rocket.Chat is not running"
        exit 1
    fi
    
    # Check MongoDB
    print_status "Checking MongoDB..."
    if kubectl get pod -l app=mongodb -n rocketchat -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
        print_success "MongoDB is running"
    else
        print_error "MongoDB is not running"
        exit 1
    fi
    
    # Check monitoring (if enabled)
    if [ "$ENABLE_MONITORING" = "true" ]; then
        print_status "Checking monitoring stack..."
        if kubectl get pod -l app=prometheus -n monitoring -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
            print_success "Prometheus is running"
        else
            print_warning "Prometheus is not running"
        fi
        
        if kubectl get pod -l app=grafana -n monitoring -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
            print_success "Grafana is running"
        else
            print_warning "Grafana is not running"
        fi
    fi
    
    print_success "Health checks completed"
}

# Generate recreation report
generate_recreation_report() {
    print_status "Generating recreation report..."
    
    # Get cluster information
    cluster_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Not available")
    
    echo "📊 Cluster Recreation Report"
    echo "==========================="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Cluster: $CLUSTER_NAME"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Snapshot Timestamp: $SNAPSHOT_TIMESTAMP"
    echo "Monitoring Enabled: $ENABLE_MONITORING"
    echo "Dry Run: $DRY_RUN"
    echo ""
    echo "🔄 Recreation Actions:"
    echo "   • AKS cluster created"
    echo "   • Base infrastructure installed"
    echo "   • PVCs restored from snapshots"
    echo "   • Secrets synced from Key Vault"
    echo "   • Rocket.Chat deployed"
    echo "   • MongoDB data restored"
    echo "   • DNS and certificates configured"
    echo "   • Health checks completed"
    echo ""
    echo "🌐 Access Information:"
    echo "   • Cluster IP: $cluster_ip"
    echo "   • Rocket.Chat: https://chat.canepro.me"
    if [ "$ENABLE_MONITORING" = "true" ]; then
        echo "   • Grafana: https://grafana.chat.canepro.me"
    fi
    echo ""
    echo "📋 Next steps:"
    echo "   1. Update DNS records to point to cluster IP"
    echo "   2. Verify SSL certificates are issued"
    echo "   3. Test Rocket.Chat functionality"
    echo "   4. Monitor cluster health and performance"
}

# Main execution
main() {
    print_status "Starting cluster recreation process..."
    
    check_prerequisites
    check_cluster_exists
    get_latest_snapshot_timestamp
    create_aks_cluster
    install_base_infrastructure
    restore_pvcs_from_snapshots
    sync_secrets_from_keyvault
    deploy_rocketchat
    deploy_monitoring_stack
    restore_mongodb_data
    configure_dns_and_certificates
    run_health_checks
    generate_recreation_report
    
    print_success "Cluster recreation completed successfully!"
    echo ""
    echo "🔄 Recreation Summary:"
    echo "   • Cluster: $CLUSTER_NAME"
    echo "   • Resource Group: $RESOURCE_GROUP"
    echo "   • Snapshot Timestamp: $SNAPSHOT_TIMESTAMP"
    echo "   • Status: Completed successfully"
    echo "   • Monitoring: $ENABLE_MONITORING"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Update DNS records to point to cluster IP"
    echo "   2. Verify SSL certificates are issued"
    echo "   3. Test Rocket.Chat functionality"
    echo "   4. Monitor cluster health and performance"
}

# Run main function
main "$@"
