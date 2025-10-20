#!/bin/bash

# Update Enhanced CPU and Memory Monitoring Dashboard
# This script deploys the enhanced Rocket.Chat dashboard with comprehensive CPU and memory monitoring
# Author: AI Assistant
# Date: $(date)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "No active Kubernetes cluster connection"
        exit 1
    fi
    
    # Check if monitoring namespace exists
    if ! kubectl get namespace monitoring &> /dev/null; then
        error "monitoring namespace does not exist"
        exit 1
    fi
    
    # Check if Prometheus is running
    if ! kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus &> /dev/null; then
        warning "Prometheus pods not found in monitoring namespace"
    fi
    
    # Check if Grafana is running
    if ! kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana &> /dev/null; then
        warning "Grafana pods not found in monitoring namespace"
    fi
    
    success "Prerequisites check completed"
}

# Backup existing dashboard
backup_existing_dashboard() {
    info "Creating backup of existing dashboard..."
    
    local backup_dir="./backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    if kubectl get configmap rocket-chat-dashboard-comprehensive -n monitoring &> /dev/null; then
        kubectl get configmap rocket-chat-dashboard-comprehensive -n monitoring -o yaml > "$backup_dir/rocket-chat-dashboard-comprehensive-backup.yaml"
        success "Dashboard backup created at: $backup_dir/rocket-chat-dashboard-comprehensive-backup.yaml"
    else
        warning "No existing dashboard found to backup"
    fi
}

# Deploy enhanced dashboard
deploy_enhanced_dashboard() {
    info "Deploying enhanced CPU and memory monitoring dashboard..."
    
    local dashboard_file="../monitoring/rocket-chat-dashboard-comprehensive-configmap.yaml"
    
    if [[ ! -f "$dashboard_file" ]]; then
        error "Dashboard file not found: $dashboard_file"
        exit 1
    fi
    
    # Apply the enhanced dashboard
    if kubectl apply -f "$dashboard_file"; then
        success "Enhanced dashboard deployed successfully"
    else
        error "Failed to deploy enhanced dashboard"
        exit 1
    fi
    
    # Wait for Grafana to pick up the new dashboard (if dashboard sidecar is enabled)
    info "Waiting for Grafana to reload dashboard..."
    sleep 10
    
    # Restart Grafana pods to ensure dashboard is loaded
    info "Restarting Grafana pods to ensure dashboard reload..."
    if kubectl rollout restart deployment -n monitoring -l app.kubernetes.io/name=grafana &> /dev/null; then
        success "Grafana restart initiated"
    else
        warning "Could not restart Grafana (may not be needed)"
    fi
}

# Verify deployment
verify_deployment() {
    info "Verifying deployment..."
    
    # Check if ConfigMap was created/updated
    if kubectl get configmap rocket-chat-dashboard-comprehensive -n monitoring &> /dev/null; then
        success "Dashboard ConfigMap is present"
    else
        error "Dashboard ConfigMap not found"
        return 1
    fi
    
    # Check Grafana pod status
    local grafana_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | wc -l)
    if [[ $grafana_pods -gt 0 ]]; then
        success "Grafana pods are present ($grafana_pods pod(s))"
        
        # Wait for Grafana pods to be ready
        info "Waiting for Grafana pods to be ready..."
        if kubectl wait --for=condition=ready pod -n monitoring -l app.kubernetes.io/name=grafana --timeout=60s &> /dev/null; then
            success "Grafana pods are ready"
        else
            warning "Grafana pods may still be starting up"
        fi
    else
        warning "No Grafana pods found"
    fi
    
    # Check Prometheus pod status
    local prometheus_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | wc -l)
    if [[ $prometheus_pods -gt 0 ]]; then
        success "Prometheus pods are present ($prometheus_pods pod(s))"
    else
        warning "No Prometheus pods found - metrics may not be available"
    fi
}

# Display access information
show_access_info() {
    info "Dashboard deployment completed successfully!"
    echo ""
    success "🎉 Enhanced CPU and Memory Monitoring Features Added:"
    echo "   ✅ CPU Utilization with limits comparison"
    echo "   ✅ Memory Usage vs Limits visualization"
    echo "   ✅ Resource efficiency metrics"
    echo "   ✅ Node-level resource monitoring"
    echo "   ✅ Historical resource trends"
    echo "   ✅ MongoDB resource usage tracking"
    echo ""
    
    info "📊 New Dashboard Panels Added:"
    echo "   • Panel 15: CPU Utilization (%) - Shows usage vs limits"
    echo "   • Panel 16: Memory Usage vs Limits - Visual comparison"
    echo "   • Panel 29: CPU Usage Efficiency (%) - Resource efficiency"
    echo "   • Panel 30: Memory Usage Efficiency (%) - Memory efficiency"
    echo "   • Panel 31: Node CPU Usage - Cluster-wide CPU"
    echo "   • Panel 32: Node Memory Usage - Cluster-wide memory"
    echo "   • Panel 33: Resource Usage Trends (24h) - Historical data"
    echo "   • Panel 34: MongoDB Resource Usage - Database monitoring"
    echo ""
    
    info "🔗 To access Grafana dashboard:"
    
    # Try to get Grafana service info
    local grafana_service=$(kubectl get svc -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | head -1)
    if [[ -n "$grafana_service" ]]; then
        local service_name=$(echo "$grafana_service" | awk '{print $1}')
        local service_type=$(echo "$grafana_service" | awk '{print $2}')
        
        if [[ "$service_type" == "LoadBalancer" ]]; then
            local external_ip=$(kubectl get svc "$service_name" -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
            if [[ "$external_ip" != "pending" && -n "$external_ip" ]]; then
                echo "   External URL: http://$external_ip"
            else
                echo "   LoadBalancer IP: Pending (check later with: kubectl get svc $service_name -n monitoring)"
            fi
        else
            echo "   Port Forward: kubectl port-forward -n monitoring svc/$service_name 3000:80"
            echo "   Then access: http://localhost:3000"
        fi
    else
        echo "   Port Forward: kubectl port-forward -n monitoring svc/grafana 3000:80"
        echo "   Then access: http://localhost:3000"
    fi
    
    echo ""
    echo "   📋 Dashboard: Search for 'Rocket.Chat Comprehensive Production Monitoring'"
    echo "   🔐 Default credentials may be admin/prom-operator (check your configuration)"
    echo ""
    
    success "🚀 Your enhanced monitoring dashboard is ready!"
}

# Main execution
main() {
    echo "======================================"
    echo "🚀 Enhanced CPU & Memory Monitoring Dashboard Deployment"
    echo "======================================"
    echo ""
    
    check_prerequisites
    backup_existing_dashboard
    deploy_enhanced_dashboard
    verify_deployment
    show_access_info
    
    echo ""
    success "✅ Deployment completed successfully!"
}

# Execute main function
main "$@"
